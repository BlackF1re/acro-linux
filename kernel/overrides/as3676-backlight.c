// SPDX-License-Identifier: GPL-2.0-only
/*
 * AS3676 backlight and LED support for Sony Fuji/Hikari.
 *
 * The physical Hikari mapping is fixed by Sony's leds-fuji_hikari.c:
 *   LCD backlight: current sinks 1, 2 and 6
 *   button backlight: RGB1, RGB2 and RGB3
 *   notification red/green/blue: current sinks 41/42/43
 *
 * Keep the driver intentionally small: LED-core software blinking is enough
 * for bring-up and avoids carrying the Android-era pattern/ALS sysfs ABI.
 */

#include <linux/backlight.h>
#include <linux/bitops.h>
#include <linux/delay.h>
#include <linux/i2c.h>
#include <linux/kernel.h>
#include <linux/leds.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/regmap.h>

#define AS3676_CONTROL		0x00
#define AS3676_CURR12_CTRL	0x01
#define AS3676_CURR_RGB_CTRL	0x02
#define AS3676_CURR4_CTRL	0x04
#define AS3676_CURR1		0x09
#define AS3676_CURR2		0x0a
#define AS3676_RGB1		0x0b
#define AS3676_RGB2		0x0c
#define AS3676_RGB3		0x0d
#define AS3676_CURR41		0x13
#define AS3676_CURR42		0x14
#define AS3676_CURR43		0x15
#define AS3676_DCDC1		0x21
#define AS3676_DCDC2		0x22
#define AS3676_CURR6		0x2f
#define AS3676_ID1		0x3e
#define AS3676_ID2		0x3f

#define AS3676_ID1_VALUE	0xae
#define AS3676_ID2_MASK		0xf0
#define AS3676_ID2_VALUE	0x50

/*
 * Exact Sony Ericsson Hikari/Fuji AS3676 step-up startup sequence from
 * leds-as3676_semc.c.  Writing current-sink values without this sequence can
 * make sysfs brightness look correct while the LCD LED boost converter is
 * still off.
 */
#define HIKARI_AS3676_DCDC1		0x62
#define HIKARI_AS3676_DCDC2_PRECHARGE	0x0c
#define HIKARI_AS3676_CONTROL_ON	0x0d
#define HIKARI_AS3676_DCDC2_ON		0x8c
#define HIKARI_AS3676_STARTUP_US	12000

/* One register step is 150 uA; Hikari declares 20 mA maximum for all LEDs. */
#define HIKARI_LED_MAX_UA	20000
#define AS3676_FULL_SCALE_UA	38250

struct as3676;

struct as3676_led {
	struct led_classdev cdev;
	struct as3676 *as;
	u8 current_reg;
	u8 mode_shift;
	bool button_group;
};

struct as3676 {
	struct regmap *regmap;
	struct backlight_device *bl;
	struct mutex lock;
	struct as3676_led button;
	struct as3676_led red;
	struct as3676_led green;
	struct as3676_led blue;
};

static int as3676_hikari_start_dcdc(struct device *dev, struct as3676 *as)
{
	unsigned int control, dcdc1, dcdc2;
	int ret;

	/*
	 * This ordering and 12 ms dwell are hardware initialization, not a
	 * brightness policy.  Keep them byte-for-byte equivalent to Sony's Hikari
	 * driver so the step-up converter is actually running before sinks 1/2/6
	 * are asked for current.
	 */
	ret = regmap_write(as->regmap, AS3676_DCDC1, HIKARI_AS3676_DCDC1);
	if (ret)
		return ret;
	ret = regmap_write(as->regmap, AS3676_DCDC2,
			   HIKARI_AS3676_DCDC2_PRECHARGE);
	if (ret)
		return ret;
	ret = regmap_write(as->regmap, AS3676_CONTROL,
			   HIKARI_AS3676_CONTROL_ON);
	if (ret)
		return ret;

	usleep_range(HIKARI_AS3676_STARTUP_US,
		     HIKARI_AS3676_STARTUP_US + 500);

	ret = regmap_write(as->regmap, AS3676_DCDC2, HIKARI_AS3676_DCDC2_ON);
	if (ret)
		return ret;

	/* Read back the three control registers for physical bring-up evidence. */
	ret = regmap_read(as->regmap, AS3676_CONTROL, &control);
	if (ret)
		return ret;
	ret = regmap_read(as->regmap, AS3676_DCDC1, &dcdc1);
	if (ret)
		return ret;
	ret = regmap_read(as->regmap, AS3676_DCDC2, &dcdc2);
	if (ret)
		return ret;

	dev_info(dev, "Hikari DCDC started: CTRL=%#x DCDC1=%#x DCDC2=%#x\n",
		 control, dcdc1, dcdc2);

	if (control != HIKARI_AS3676_CONTROL_ON ||
	    dcdc1 != HIKARI_AS3676_DCDC1 ||
	    dcdc2 != HIKARI_AS3676_DCDC2_ON)
		dev_warn(dev,
			 "Hikari DCDC readback differs from Sony startup values\n");

	return 0;
}

static int as3676_backlight_update_status(struct backlight_device *bl)
{
	struct as3676 *as = bl_get_data(bl);
	u8 brightness = backlight_get_brightness(bl);
	int ret;

	mutex_lock(&as->lock);

	ret = regmap_write(as->regmap, AS3676_CURR1, brightness);
	if (ret)
		goto out;
	ret = regmap_write(as->regmap, AS3676_CURR2, brightness);
	if (ret)
		goto out;
	ret = regmap_write(as->regmap, AS3676_CURR6, brightness);
	if (ret)
		goto out;

	/* Current 1 and 2 use fields [1:0] and [3:2], normal-current mode = 1. */
	ret = regmap_update_bits(as->regmap, AS3676_CURR12_CTRL, 0x0f,
				 brightness ? 0x05 : 0x00);
	if (ret)
		goto out;

	/* Current 6 uses bits [7:6] of curr_rgb_control. */
	ret = regmap_update_bits(as->regmap, AS3676_CURR_RGB_CTRL, 0xc0,
				 brightness ? 0x40 : 0x00);

out:
	mutex_unlock(&as->lock);
	return ret;
}

static const struct backlight_ops as3676_backlight_ops = {
	.options = BL_CORE_SUSPENDRESUME,
	.update_status = as3676_backlight_update_status,
};

static u8 as3676_led_current(enum led_brightness brightness)
{
	return DIV_ROUND_CLOSEST((unsigned int)brightness * HIKARI_LED_MAX_UA,
				 AS3676_FULL_SCALE_UA);
}

static int as3676_led_set(struct led_classdev *cdev,
			   enum led_brightness brightness)
{
	struct as3676_led *led = container_of(cdev, struct as3676_led, cdev);
	struct as3676 *as = led->as;
	u8 current_code = as3676_led_current(brightness);
	int ret;

	mutex_lock(&as->lock);

	if (led->button_group) {
		ret = regmap_write(as->regmap, AS3676_RGB1, current_code);
		if (ret)
			goto out;
		ret = regmap_write(as->regmap, AS3676_RGB2, current_code);
		if (ret)
			goto out;
		ret = regmap_write(as->regmap, AS3676_RGB3, current_code);
		if (ret)
			goto out;

		/* RGB1/2/3 mode fields are [1:0], [3:2], [5:4]. */
		ret = regmap_update_bits(as->regmap, AS3676_CURR_RGB_CTRL, 0x3f,
					 brightness ? 0x15 : 0x00);
	} else {
		ret = regmap_write(as->regmap, led->current_reg, current_code);
		if (ret)
			goto out;
		ret = regmap_update_bits(as->regmap, AS3676_CURR4_CTRL,
					 0x03 << led->mode_shift,
					 brightness ? BIT(led->mode_shift) : 0);
	}

out:
	mutex_unlock(&as->lock);
	return ret;
}

static int as3676_register_led(struct device *dev, struct as3676 *as,
				struct as3676_led *led, const char *name,
				u8 current_reg, u8 mode_shift,
				bool button_group)
{
	led->as = as;
	led->current_reg = current_reg;
	led->mode_shift = mode_shift;
	led->button_group = button_group;
	led->cdev.name = name;
	led->cdev.max_brightness = LED_FULL;
	led->cdev.brightness_set_blocking = as3676_led_set;

	return devm_led_classdev_register(dev, &led->cdev);
}

static const struct regmap_config as3676_regmap_config = {
	.reg_bits = 8,
	.val_bits = 8,
	.max_register = 0xbf,
};

static int as3676_probe(struct i2c_client *client)
{
	struct backlight_properties props = {
		.type = BACKLIGHT_RAW,
		.max_brightness = 127,
		.brightness = 32,
		/*
		 * Prepare Sony's DCDC at probe, but keep sinks 1/2/6 dark until the
		 * DRM panel core calls backlight_enable() after a successful panel
		 * enable. This makes a lit LCD a meaningful KMS milestone.
		 */
		.power = BACKLIGHT_POWER_OFF,
	};
	struct as3676 *as;
	unsigned int id1, id2;
	int ret;

	as = devm_kzalloc(&client->dev, sizeof(*as), GFP_KERNEL);
	if (!as)
		return -ENOMEM;

	mutex_init(&as->lock);
	as->regmap = devm_regmap_init_i2c(client, &as3676_regmap_config);
	if (IS_ERR(as->regmap))
		return PTR_ERR(as->regmap);

	ret = regmap_read(as->regmap, AS3676_ID1, &id1);
	if (ret)
		return ret;
	ret = regmap_read(as->regmap, AS3676_ID2, &id2);
	if (ret)
		return ret;
	if (id1 != AS3676_ID1_VALUE || (id2 & AS3676_ID2_MASK) != AS3676_ID2_VALUE)
		return dev_err_probe(&client->dev, -ENODEV,
				     "unexpected AS3676 IDs %#x %#x\n", id1, id2);

	ret = as3676_hikari_start_dcdc(&client->dev, as);
	if (ret)
		return dev_err_probe(&client->dev, ret,
				     "failed to start Hikari LCD DCDC\n");

	as->bl = devm_backlight_device_register(&client->dev, "as3676-backlight",
					     &client->dev, as,
					     &as3676_backlight_ops, &props);
	if (IS_ERR(as->bl))
		return PTR_ERR(as->bl);

	ret = as3676_register_led(&client->dev, as, &as->button,
				  "button-backlight", 0, 0, true);
	if (ret)
		return ret;
	ret = as3676_register_led(&client->dev, as, &as->red,
				  "red", AS3676_CURR41, 0, false);
	if (ret)
		return ret;
	ret = as3676_register_led(&client->dev, as, &as->green,
				  "green", AS3676_CURR42, 2, false);
	if (ret)
		return ret;
	ret = as3676_register_led(&client->dev, as, &as->blue,
				  "blue", AS3676_CURR43, 4, false);
	if (ret)
		return ret;

	dev_info(&client->dev,
		 "AS3676 detected (IDs %#x %#x): LCD DCDC ready; backlight waits for DRM panel enable\n",
		 id1, id2);

	return backlight_update_status(as->bl);
}

static const struct of_device_id as3676_of_match[] = {
	{ .compatible = "ams,as3676-backlight" },
	{ }
};
MODULE_DEVICE_TABLE(of, as3676_of_match);

static struct i2c_driver as3676_driver = {
	.driver = {
		.name = "as3676-hikari",
		.of_match_table = as3676_of_match,
	},
	.probe = as3676_probe,
};
module_i2c_driver(as3676_driver);

MODULE_DESCRIPTION("AS3676 backlight and LED support for Sony Hikari");
MODULE_LICENSE("GPL");
