#!/bin/bash
make && scp ess.bin dice@dicepi1bp-nc.det.csiro.au:~/ && ssh dice@dicepi1bp-nc.det.csiro.au icezerotools/icezprog ess.bin
