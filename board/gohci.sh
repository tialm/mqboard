#! /bin/bash
export PYBOARD_DEVICE=${PYBOARD_DEVICE:-/dev/ttyUSB0}
export PATH=$HOME/bin:$PATH
cd $(dirname $0)
pwd

echo "---- wiping flash clean ----"
if ! pyboard.py rm_rf.py; then
    echo OOPS
    exit 1
fi

echo "----- uploading board files -----"
pyboard.py -f cp board.py boot.py logging.py main.py mqtt.py :
board_config=$HOME/board_config_esp32.py
[ -f $board_config ] || board_config=board_config.py # for local testing
pyboard.py -f cp $board_config :board_config.py
# now check they're all there
out=$(pyboard.py -f ls)
if [[ "$out" != *board.py*board_config.py*boot.py*logging.py*main.py* ]]; then
	echo OOPS, got: "$out"
	exit 1
fi

echo "----- resetting -----"
python3 -c "import serial; s=serial.serial_for_url('$PYBOARD_DEVICE'); s.setDTR(0); s.setDTR(1)"
sleep 3
out=$(timeout 1m pyboard.py -c 'print(3+4)')
if [[ "$out" != *7* ]]; then
	echo OOPS, got: "$out"
	exit 1
fi
echo did reset

echo "----- test boot -----"
out=$(timeout 6s pyboard.py test-boot.py)
if [[ "$out" == *OOPS* || "$out" != *"SAFE MODE"*"Reset cause: SOFT_RESET"* ]]; then
	echo OOPS, got: "$out"
	exit 1
fi
echo "$out" | head -3
echo "$out" | egrep -i 'boot|safe|reset'
pyboard.py -f cp mqtt.py :

echo "----- test main -----"
out=$(pyboard.py test-main.py)
if [[ "$out" == *OOPS* || \
    "$out" != *"no module named"*"module1 OK"*"module2 OK"*"function takes"* \
    ]]; then
	echo OOPS, got: "$out"
	exit 1
fi
echo "$out" | egrep OK

echo "----- test board -----"
cmd="from board import *; print(len(kind)>2, act_led!=False, fail_led!=False, bat_volt_pin, bat_fct)"
out=$(pyboard.py -c "$cmd")
if [[ "$out" != *"True True True None 2"* ]]; then
	echo OOPS, got: "$out"
	exit 1
fi
echo "$out"

echo "----- turn the LED on for grins -----"
pyboard.py -c "from board import *; act_led(1)"

echo 'SUCCESS!'
