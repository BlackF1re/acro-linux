// SPDX-License-Identifier: GPL-2.0-only
/* Native V4L2 tuning and RDS acceptance probe; no audio playback. */
#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	struct v4l2_frequency frequency = { .type = V4L2_TUNER_RADIO };
	struct v4l2_capability capability = { 0 };
	unsigned int blocks = 0, corrected = 0, errors = 0;
	char *end;
	unsigned long khz;
	int fd, result = 1;

	if (argc < 2 || argc > 3 || (argc == 3 && strcmp(argv[2], "seek"))) {
		fprintf(stderr, "Usage: %s FREQUENCY_KHZ [seek]\n", argv[0]);
		return 1;
	}
	errno = 0;
	khz = strtoul(argv[1], &end, 10);
	if (errno || *end || khz < 87500 || khz > 108000)
		return 1;
	fd = open("/dev/radio0", O_RDWR | O_NONBLOCK);
	if (fd < 0) {
		perror("open radio0");
		return 1;
	}
	if (ioctl(fd, VIDIOC_QUERYCAP, &capability)) {
		perror("querycap");
		goto out;
	}
	printf("driver=%s card=%s\n", capability.driver, capability.card);
	frequency.frequency = khz * 16;
	if (ioctl(fd, VIDIOC_S_FREQUENCY, &frequency)) {
		perror("tune");
		goto out;
	}
	if (argc == 3) {
		struct v4l2_hw_freq_seek seek = {
			.type = V4L2_TUNER_RADIO, .seek_upward = 1,
			.spacing = 100000,
		};
		int flags = fcntl(fd, F_GETFL);

		if (flags < 0 || fcntl(fd, F_SETFL, flags & ~O_NONBLOCK))
			goto out;
		if (ioctl(fd, VIDIOC_S_HW_FREQ_SEEK, &seek))
			perror("seek");
		if (fcntl(fd, F_SETFL, flags))
			goto out;
	}
	if (ioctl(fd, VIDIOC_G_FREQUENCY, &frequency)) {
		perror("get frequency");
		goto out;
	}
	printf("frequency_mhz=%.3f\n", frequency.frequency / 16000.0);
	fflush(stdout);
	for (int second = 0; second < 20; second++) {
		struct pollfd pending = { .fd = fd, .events = POLLIN };
		struct v4l2_rds_data data[256];
		int ready = poll(&pending, 1, 1000);
		ssize_t size;

		if (ready < 0) {
			perror("poll");
			goto out;
		}
		if (!ready)
			continue;
		size = read(fd, data, sizeof(data));
		if (size < 0) {
			if (errno == EAGAIN)
				continue;
			perror("read RDS");
			goto out;
		}
		for (size_t i = 0; i < (size_t)size / sizeof(data[0]); i++) {
			blocks++;
			if (data[i].block & V4L2_RDS_BLOCK_ERROR)
				errors++;
			else if (data[i].block & V4L2_RDS_BLOCK_CORRECTED)
				corrected++;
			printf("RDS %04x block=%02x\n",
			       data[i].msb * 256 + data[i].lsb, data[i].block);
		}
	}
	printf("blocks=%u clean=%u corrected=%u uncorrectable=%u\n",
	       blocks, blocks - corrected - errors, corrected, errors);
	/* No RDS blocks is inconclusive, not a receiver correctness failure. */
	result = blocks ? 0 : 2;
out:
	close(fd);
	return result;
}
