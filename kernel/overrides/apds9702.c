// SPDX-License-Identifier: GPL-2.0-only
/*
 * Avago APDS9702 proximity sensor
 *
 * The device is configured by sending its 16-bit control word as an SMBus
 * command byte followed by a data byte.  Detection itself is reported on the
 * active-low DOUT pin.  This is based on the GPL Sony Mobile driver, converted
 * from the Android input ABI to IIO.
 */

#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/i2c.h>
#include <linux/interrupt.h>
#include <linux/iio/events.h>
#include <linux/iio/iio.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/property.h>

#define APDS9702_HIKARI_CONTROL	0xdfbc

struct apds9702_data {
	struct i2c_client *client;
	struct gpio_desc *dout;
	struct mutex lock;
	u16 control;
	bool event_enabled;
};

static int apds9702_set_active(struct apds9702_data *data, bool active)
{
	u16 word = active ? data->control : 0;

	return i2c_smbus_write_byte_data(data->client, word & 0xff, word >> 8);
}

static int apds9702_read_detection(struct apds9702_data *data)
{
	int ret;

	ret = gpiod_get_value_cansleep(data->dout);
	return ret < 0 ? ret : !!ret;
}

static int apds9702_read_raw(struct iio_dev *indio_dev,
			     const struct iio_chan_spec *chan, int *val,
			     int *val2, long mask)
{
	struct apds9702_data *data = iio_priv(indio_dev);
	bool temporary;
	int ret;

	if (mask != IIO_CHAN_INFO_RAW)
		return -EINVAL;

	mutex_lock(&data->lock);
	temporary = !data->event_enabled;
	if (temporary) {
		ret = apds9702_set_active(data, true);
		if (ret)
			goto out;
		/* Five milliseconds is Sony's retry interval; allow two periods. */
		msleep(10);
	}

	ret = apds9702_read_detection(data);
	if (ret >= 0) {
		*val = ret;
		ret = IIO_VAL_INT;
	}

	if (temporary) {
		int off_ret = apds9702_set_active(data, false);

		if (ret >= 0 && off_ret)
			ret = off_ret;
	}
out:
	mutex_unlock(&data->lock);
	return ret;
}

static int apds9702_read_event_config(struct iio_dev *indio_dev,
				      const struct iio_chan_spec *chan,
				      enum iio_event_type type,
				      enum iio_event_direction dir)
{
	struct apds9702_data *data = iio_priv(indio_dev);

	return data->event_enabled;
}

static int apds9702_write_event_config(struct iio_dev *indio_dev,
				       const struct iio_chan_spec *chan,
				       enum iio_event_type type,
				       enum iio_event_direction dir, bool state)
{
	struct apds9702_data *data = iio_priv(indio_dev);
	int ret = 0;

	mutex_lock(&data->lock);
	if (state != data->event_enabled) {
		ret = apds9702_set_active(data, state);
		if (!ret)
			data->event_enabled = state;
	}
	mutex_unlock(&data->lock);
	return ret;
}

static irqreturn_t apds9702_irq(int irq, void *arg)
{
	struct iio_dev *indio_dev = arg;
	struct apds9702_data *data = iio_priv(indio_dev);
	enum iio_event_direction direction;
	int detected;

	mutex_lock(&data->lock);
	if (!data->event_enabled) {
		mutex_unlock(&data->lock);
		return IRQ_HANDLED;
	}
	detected = apds9702_read_detection(data);
	mutex_unlock(&data->lock);
	if (detected < 0)
		return IRQ_HANDLED;
	direction = detected ? IIO_EV_DIR_RISING : IIO_EV_DIR_FALLING;

	iio_push_event(indio_dev,
		IIO_UNMOD_EVENT_CODE(IIO_PROXIMITY, 0, IIO_EV_TYPE_THRESH,
			direction),
		iio_get_time_ns(indio_dev));
	return IRQ_HANDLED;
}

static const struct iio_event_spec apds9702_events[] = {
	{
		.type = IIO_EV_TYPE_THRESH,
		.dir = IIO_EV_DIR_EITHER,
		.mask_separate = BIT(IIO_EV_INFO_ENABLE),
	},
};

static const struct iio_chan_spec apds9702_channels[] = {
	{
		.type = IIO_PROXIMITY,
		.info_mask_separate = BIT(IIO_CHAN_INFO_RAW),
		.event_spec = apds9702_events,
		.num_event_specs = ARRAY_SIZE(apds9702_events),
	},
};

static const struct iio_info apds9702_info = {
	.read_raw = apds9702_read_raw,
	.read_event_config = apds9702_read_event_config,
	.write_event_config = apds9702_write_event_config,
};

static int apds9702_probe(struct i2c_client *client)
{
	struct iio_dev *indio_dev;
	struct apds9702_data *data;
	u32 control = APDS9702_HIKARI_CONTROL;
	int ret;

	indio_dev = devm_iio_device_alloc(&client->dev, sizeof(*data));
	if (!indio_dev)
		return -ENOMEM;
	data = iio_priv(indio_dev);
	data->client = client;
	mutex_init(&data->lock);

	device_property_read_u32(&client->dev, "avago,control-word", &control);
	if (control > U16_MAX)
		return dev_err_probe(&client->dev, -EINVAL,
				     "control word exceeds 16 bits\n");
	data->control = control;
	data->dout = devm_gpiod_get(&client->dev, "dout", GPIOD_IN);
	if (IS_ERR(data->dout))
		return dev_err_probe(&client->dev, PTR_ERR(data->dout),
				     "failed to get DOUT\n");

	ret = apds9702_set_active(data, false);
	if (ret)
		return dev_err_probe(&client->dev, ret, "device did not respond\n");

	indio_dev->name = "apds9702";
	indio_dev->info = &apds9702_info;
	indio_dev->modes = INDIO_DIRECT_MODE;
	indio_dev->channels = apds9702_channels;
	indio_dev->num_channels = ARRAY_SIZE(apds9702_channels);
	i2c_set_clientdata(client, indio_dev);

	if (client->irq > 0) {
		ret = devm_request_threaded_irq(&client->dev, client->irq, NULL,
						apds9702_irq, IRQF_ONESHOT |
						IRQF_TRIGGER_RISING |
						IRQF_TRIGGER_FALLING,
						dev_name(&client->dev), indio_dev);
		if (ret)
			return dev_err_probe(&client->dev, ret,
					     "failed to request DOUT IRQ\n");
	}

	return devm_iio_device_register(&client->dev, indio_dev);
}

static void apds9702_remove(struct i2c_client *client)
{
	struct iio_dev *indio_dev = i2c_get_clientdata(client);
	struct apds9702_data *data = iio_priv(indio_dev);

	apds9702_set_active(data, false);
}

static const struct of_device_id apds9702_of_match[] = {
	{ .compatible = "avago,apds9702" },
	{ }
};
MODULE_DEVICE_TABLE(of, apds9702_of_match);

static struct i2c_driver apds9702_driver = {
	.driver = {
		.name = "apds9702",
		.of_match_table = apds9702_of_match,
	},
	.probe = apds9702_probe,
	.remove = apds9702_remove,
};
module_i2c_driver(apds9702_driver);

MODULE_AUTHOR("Sony Mobile Communications AB; mainline IIO conversion by Hikari Linux project");
MODULE_DESCRIPTION("Avago APDS9702 proximity sensor");
MODULE_LICENSE("GPL");
