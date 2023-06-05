#!/bin/bash
make && scp ess.bin dice@dicepi:~/ && ssh dice@dicepi icezerotools/icezprog ess.bin
