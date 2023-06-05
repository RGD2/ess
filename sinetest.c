#define SPEED B2500000 
#define PORT "/dev/ttyAMA0"
#include <errno.h> 
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <math.h>
#include <time.h>


struct timespec walltime(){
	struct timespec start_time;
	clock_gettime(CLOCK_TAI, &start_time);
	return start_time;
}

long time_delta(struct timespec start_time, struct timespec end_time){
	long diffInNanos = (end_time.tv_sec - start_time.tv_sec) * (long)1e9 + (end_time.tv_nsec - start_time.tv_nsec);
	return diffInNanos;
}

u_int16_t swapped(u_int16_t v)
{
	return ((v>>8)|(v<<8));
}

void main()
{
    int fd; 
	const char *port = PORT;
    fd = open(port, O_RDWR | O_NOCTTY | O_SYNC);
    
    struct termios tty;
    tcgetattr(fd, &tty);
    cfsetospeed(&tty, (speed_t)SPEED);
    cfsetispeed(&tty, (speed_t)SPEED);

    tty.c_cflag |= (CLOCAL | CREAD);    /* ignore modem controls */
    tty.c_cflag &= ~CSIZE;
    tty.c_cflag |= CS8;         /* 8-bit characters */
    tty.c_cflag &= ~PARENB;     /* no parity bit */
    tty.c_cflag &= ~CSTOPB;     /* only need 1 stop bit */
    tty.c_cflag &= ~CRTSCTS;    /* no hardware flowcontrol */

    /* setup for non-canonical mode */
    tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
    tty.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    tty.c_oflag &= ~OPOST;

    /* fetch 5 byte packets as they become available, but also return smaller ones if they occur, after a delay */
    tty.c_cc[VMIN] = 5; // these are both unsigned char, 0-255 is valid. 
    tty.c_cc[VTIME] = 1; // timer unfortunately tenths of second.

    tcsetattr(fd, TCSANOW, &tty);
   

	// generate fake pressure signal data
	
	double frac = 0.0l;
	u_int16_t values[1440];
	for (int i=0; i<1440; i++)
	{
		frac = ((double)i)*2*M_PI/1440;
		values[i] =swapped((u_int16_t)(32767*(0.7*sin(frac-0.5*M_PI)+0.21))+32767);
	}

	u_int16_t tcode = swapped(8333);

	// timer code
	struct timespec lt, now = walltime();
	double dt = 0.0;
	// main loop

	int i = 0;

		while(1)
		{

			now = walltime();
			dt = time_delta(lt, now);
			lt.tv_sec = now.tv_sec;
			lt.tv_nsec = now.tv_nsec;

			write(fd, (unsigned char*)&tcode, 2);
			write(fd, (unsigned char*)(values + i), 2);
			tcdrain(fd); // wait for transmission to finish!


			//printf("%i \n", swapped(values[i]));

			i++;
			if (i==1440)
				i=0;


			usleep(floor((208e-6 - dt)*1e6));
		}
}
