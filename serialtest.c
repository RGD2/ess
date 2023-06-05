#include <errno.h> 
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>


// B115200, B230400, B9600, B19200, B38400, B57600, etc
// try:
// tail -17 /usr/include/arm-linux-gnueabihf/bits/termios-baud.hh
// But we have this rate working (from 40MHz, quad-rate clk is maxcount==4, for 5 states, to reach a 10MHz sample rate)
// (40MHz was required for the application, derived from icezero's 100MHz clock)

#define SPEED B2500000

void main()
{
    int fd; 
	const char *port = "/dev/ttyAMA0";
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
	// condition to return depends on config, but either way doesn't depend on EOL, whereas canonical mode does, whether blocking or not.

    tcsetattr(fd, TCSANOW, &tty);
    
    // can now do writes/reads: fd, buffer, length
    // valid write should return same number as length
    // tcdrain(fd); // after a write does a wait for a write to complete.
    // after which you can get a timestamp, 
    // Then the read will wait for the expected number of bytes set into VLEN
    // can also re-get tty with tcgetattr, and update settings after a struct write with tcsetattr, so could change the expected length for 
    // every packet if they should change & are predictable. 
    // VTIME then ends up being a anti-lockup feature, as the read will return on one OR the other: 
    // - Either expected number of bytes arrive, or 
    // - there's a timeout (min 1/10th second), which should be considered a performance-limiting but otherwise recoverable/loggable error.
    // Without VTIME, the program could end up locking up if fewer byte(s) than expected show(s) up to a query.
    // Windows, by comparison, wants you configure 5 different 32bit numbers, just to set timeouts. 

// just for example:

		while(1)
		{
			write(fd, "Hello! \n", 8);
			tcdrain(fd);

		}
}


