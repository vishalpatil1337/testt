# testt
test
tesrr
https://controlcaseint-my.sharepoint.com/:u:/g/personal/vipatil_controlcase_com/EYsjTGoL_mhDrKwo-s3XntUB4CH1X0VQnmXJeXxCUNUtHw?e=cTwfSZ


nmap -sS -Pn -p- -T4 -iL scope.txt -oA open_port --max-rtt-timeout 100ms --max-retries 3 --defeat-rst-ratelimit --min-rate 450 --max-rate 15000


for /f %i in (scope.txt) do tracert %i >> tracert_output.txt


@echo off
for /f %%i in (scope.txt) do (
    echo Tracing route to %%i >> tracert_output.txt
    tracert %%i >> tracert_output.txt
    echo. >> tracert_output.txt
)
echo All tracert results saved to tracert_output.txt
