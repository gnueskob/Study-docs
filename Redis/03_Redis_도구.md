# 레디스 도구

## 레디스 성능 측정

- 레디스는 성능 측정을 위한 `redis-benchmark` 도구 제공

```redis
redis-benchmark
====== PING_INLINE ======
  100000 requests completed in 0.84 seconds
  50 parallel clients
  3 bytes payload
  keep alive: 1

99.65% <= 1 milliseconds
99.99% <= 2 milliseconds
100.00% <= 2 milliseconds
119474.31 requests per second

====== PING_BULK ======
  100000 requests completed in 0.83 seconds
  50 parallel clients
  3 bytes payload
  keep alive: 1

99.94% <= 1 milliseconds
100.00% <= 1 milliseconds
120918.98 requests per second

====== SET ======
  100000 requests completed in 0.92 seconds
  50 parallel clients
  3 bytes payload
  keep alive: 1

...


====== MSET (10 keys) ======
  100000 requests completed in 1.24 seconds   <- (1)
  50 parallel clients                         <- (2)
  3 bytes payload                             <- (3)
  keep alive: 1                               <- (4)

95.67% <= 1 milliseconds
99.49% <= 2 milliseconds
99.94% <= 3 milliseconds
100.00% <= 3 milliseconds
80580.17 requests per second                  <- (5)
```

- (1) : 만 개의 명령을 처리하는데 걸린 시간
- (2) : 50개의 클라이언트 병렬 연결
- (3) : 저장 데이터의 크기 (3 bytes)
- (4) : 클라이언트 연결 유지 상태 정보
- (5) : 초당 처리된 명령 수

| Options          | Description                                | Default                   |
| :--------------- | :----------------------------------------- | :------------------------ |
| -h (hostname)    | 레디스 서버 호스트명                                | localhost (127.0.0.1)     |
| -p (port)        | 레디스 서버 포트                                  | 6379                      |
| -s (socket)      | 레디스 서버의 유닉스 서버 소켓                          | -                         |
| -c (clients)     | 가상 클라이언트 동시 접속 수                           | 50                        |
| -n (requests)    | 각 명령 테스트 횟수                                | 10000                     |
| -d (size)        | 테스트용 데이터 크기                                | 3* (bytes)                |
| -k (boolean)     | 가상 클라이언트 접속 유지 여부                          | 1 : keep alive / 0 : None |
| -r (keyspacelen) | 사용할 랜덤 키의 범위                               | 0                         |
| -P (numreq)      | 파이프라인 명령을 사용한 테스트, 파이프라인당 요청할 명령 수         | 0                         |
| -q               | 진행 상황은 출력하지 않고 결과만 출력                      | -                         |
| --csv            | 테스트 결과를 CSV 포맷으로 출력                        | -                         |
| -l               | 브레이크(`Ctrl + C`)를 걸기 전까지 계속 수행             | -                         |
| -t (tests)       | 쉼표(`,`)로 구분된 테스트 명령의 목록                    | -                         |
| -I               | 명령 전송 없는 연결 생성 후 브레이크(`Ctrl + C`) 입력때까지 대기 | -                         |

***

## redis-cli

- 레디스의 번들 프로그램으로서 간단한 명령어 처리와 데이터 벌크 입력과 같은 다양한 기능 제공

| Options   | Description                                       | Default   |
| :-------- | :------------------------------------------------ | :-------- |
| -h        | 접속할 서버의 호스트명                                      | 127.0.0.1 |
| -p        | 접속할 서버의 포트                                        | 6379      |
| -s        | 접속할 서버의 유닉스 서버 소켓                                 | -         |
| -a        | 서버에 PW가 설정되었을 때 연결에 필요한 PW 자동 입력                  | -         |
| -r        | 지정된 명령을 반복 횟수만큼 실행                                | -         |
| -i        | -r 옵션 사용 시 명령 사이의 대기 시간을 초 단위로 설정                 | 0         |
| -n        | 접속할 데이터베이스 인덱스 지정                                 | -         |
| -x        | 레디스 명령 입력 시 리눅스 명령행의 표준 입력으로 부터 마지막 인자를 입력받음      | -         |
| -d        | 멀티 벌크 입력 시 원시 데이터의 구분자 지정                         | (\n)      |
| -c        | 클러스터 접속 모드 사용 (추가 문자열 필요)                         | -         |
| --raw     | 멀티 벌크 입력 모드 사용. 결과는 시스템 표준 출력을 통해 나타남             | 시스템 표준 출력 |
| --latency | 서버의 명령 응답 속도를 측정하는 모드                             | -         |
| --slave   | 클러스터의 슬레이브의 연결로 에뮬레이트 하여 슬레이브가 받는 명령 목록 출력        | -         |
| --pipe    | 벌크 입력을 시스템 표준 입력으로부터 받아들임                         | -         |
| --bigkeys | 저장된 키 중 가장 긴 길이의 키와 해당 데이터의 크기 출력 (미종료시 서버 부하 원인) | -         |
| --eval    | 루아 스크립트를 서버에서 실행                                  | -         |
| --help    | 명령 목록과 예제 출력 후 종료                                 | -         |
| --version | 대화형 레디스 클라이언트 버전 출력 후 종료                          | -         |

***

## info 명령

| Parameter   | Description                    |
| :---------- | :----------------------------- |
| server      | 레디스 서버의 기초적인 정보, 프로세스 ID, 포트 등 |
| clients     | 접속 된 클라이언트 정보 및 통계             |
| memory      | 메모리 사용량 통계 정보                  |
| persistence | 영구 저장소 상태 및 통계 정보              |
| stats       | 키 사용률, 명령 개수에 대한 통계 정보         |
| replication | 복제에 대한 통계 정보                   |
| cpu         | CPU의 사용 정보에 대한 통계 정보           |
| keyspace    | 저장된 키의 개수 정보                   |