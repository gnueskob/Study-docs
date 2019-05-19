# 레디스 추가 기능

## PUB/SUB

- `Pub/Sub`은 메세지를 특정 수신자에게 직접 발송하지 못하는 곳에서 쓰이는 패턴
- Publish-Subscribe의 약자
- 발송자, 구독자가 특정 채널을 리스닝
- 발소자는 채널에 메시지를 보내고 구독자는 발송자의 메시지를 받음
- `PUBLISH` 커맨드
  - 메시지를 레디스 채널에 보내고 메시지를 받은 클라이언트 개수를 리턴
  - 메시지가 채널로 들어올 때 채널을 구독하는 클라이언트가 없다면 메시지는 소실됨

```js
// publisher.js
var redis = require("redis");
var clinet = redis.createClient();

var channel = process.argv[2]; // 커맨드 라인의 3번째 변수 할당
var command = process.argv[3];

client.publish(channel, command);
client.quit();
```

- `SUBSCRIBE` 커맨드
  - 클라이언트가 하나 이상의 채널을 구독

- `UNSUBSCRIBE` 커맨드
  - 하나 이상의 채널에서 클라이언트 구독 해지

- `PSUBSCRIBE`, `PUNSUBSCRIBE` 커맨드
  - 기존 P가 없는 명령어와 역할이 동일하나 channel 이름을 `glob`형태로 받음

- 레디스 클라이언트가 `(P)SUBSCRIBE` 명령을 실행하면 구독모드로 진입
  - `SUBSCRIBE`, `PSUBSCRIBE`, `UNSUBSCRIBE`, `PUNSUBSCRIBE` 명령만 받음

```js
// subscriber.js
var os = require("os");
var redis = require("redis");
var client = redis.createClient();

var COMMANDS = {};

COMMANDS.DATE = function () {
  var now = new DATE();
  console.log("DATE " + now.toISOString());
}

COMMANDS.PING = function () {
  console.log("PONG");
}

COMMANDS.HOSTNAME = function () {
  console.log("HOSTNAME " + os.hostname());
}

// 채널 함수 리스너
client.on("message", function (channel, commandName) {
  if (COMMANS.hasOwnProperty(commandName)) {
    var commandFunction = COMMANDS[commandName];
    commandFunction();
  } else {
    console.log("Unknown command: " + commandName);
  }
});

// 실제 채널이름을 받아 구독이 시작되는 부분
client.subscribe("global", process.argv[2]);
```

- subscriber를 실행하고 publisher에서 메시지를 보냄
- subscriber에서는 메시지를 받고 해당하는 함수를 호출하여 메시지 출력

```bash
# publisher
$ node publisher.js global PING
$ node publisher.js channel-1 DATE
$ node publisher.js channel-2 HOST
...
```

```bash
# subscriber 1
$ node subscriber.js channel-1
PONG
DATE 2019-05-16T23:13.075Z
```

```bash
# subscriber 2
$ node subscriber.js channel-2
PONG
HOSTNAME gnues.home
```

- `PUBSUB` 커맨드
  - 레디스의 `Pub/Sub`상태를 조사
  - `PUBSUB CHANNELS [pattern]`
    - 동작중인 모든 채널 반환
    - `pattern` : `glob` 형식을 가진 패턴을 명시하면 패턴에 맞는 채널이름만 반환
  - `PUBSUB NUMSUB [channel-1 ... channel-n]`
    - `SUBSCRIBE` 커맨드를 통해 채널에 접속한 클라이언트 개수 반환
    - 채널 이름을 변수로 받음
  - `PUBSUB NUMPAT`
    - `PSUBSCRIBE` 커맨드를 통해 채널에 접속한 클라이언트 개수 반환

***

## 트랜잭션

- 레디스의 트랜잭션은 순서대로 원자적으로 실행되는 커맨드들

### MULTI, EXEC, DISCARD

- 트랜잭션 커맨드
  - `MULTI` : 트랜잭션의 시작 표시
  - `EXEC` : 트랜잭션의 마지막 표시
  - `MULTI`, `EXEC` 커맨드 사이의 모든 커맨드는 직렬화되며 원자적으로 실행
  - 트랜잭션의 처리 중에는 다른 클라이언트의 요청을 처리하지 못함
- 트랜잭션의 모든 커맨드는 클라이언트의 큐에 쌓임
  - `EXEC`명령이 실행될때 비로소 서버로 전달됨
  - `EXEC`대신 `DISCARD` 명령을 사용할 경우 트랜잭션은 실행되지 않음
- 기존 SQL 데이터베이스와 달리 레디스의 트랜잭션은 트랜잭션 과정의 롤백이 없음
  - 트랜잭션 커맨드를 순서대로 실행하고 중간에 일부 명령 실패시 다음 명령으로 넘어감

### WATCH

- 키 그룹에 optimistic lock(낙관적 잠금)이 구현된 `WATCH` 명령을 통해서 조건부 트랜잭션 가능
  - `WATCH` 명령은 주시받는 키를 표시하고 `EXEC`명령 시 해당 키가 변동되었는지 확인
  - 주시받는 키를 다루는 명령이 포함된 트랜잭션을 실행할 때
    - 해당 키 값이 변동되었으면 트랜잭션 실패
    - 해당 키 값의 변동이 없으면 트랜잭션 성공
    - 즉, 해당 키 값을 다루는 명령은 특정 클라이언트 하나에서만 작동하게 됨
- `UNWATCH`를 통해 주시목록에 있는 키 제거 가능

***

## 기타

- `DBSIZE` : 레디스 서버에 존재하는 키 개수 반환

- `DEBUG SEGFAULT` : 올바르지 않은 메모리 접근을 수행해 레디스 서버 프로세스 종료
  - 버그 시뮬레이션에 유용

- `MONITOR` : 레디스 서버가 처리하는 모든 커맨드를 실시간으로 확인 가능

- `CLIENT LIST` : 클라이언트에 대한 정보 및 통계 자료, 서버에 연결된 클라이언트 목록

- `CLIENT SETNAME` : 클라이언트 이름 변경

- `CLIENT KILL` : 클라이언트 연결 종료

- `FLUSHALL` : 레디스 모든 키 삭제

- `RANDOMKEY` : 랜덤으로 키 하나를 반환

- `EXPIREAT` : `EXPIRE`와 비슷하지만 유닉스 타임스탬프를 기반으로 키의 만료시간 설정

- `PTTL` : `TTL`과 비슷하지만 키 만료시간을 `ms`단위로 반환

- `PERSIST` : 특정 키의 만료시간 갱신/제거

- `SETEX` : 키에 값을 저장할 때 만료시간도 함께 저장

- `DEL` : 한개 이상의 키를 레디스에서 삭제

- `EXISTS` : 특정 키가 존재하는지 확인

- `PING` : `PONG` 문자열을 리턴

- `MIGRATE` : 특정 키를 대상 레디스 서버로 옮김
  - 원자적으로 처리되어서 키를 옮기는 동안 두 레디스 서버가 블록됨
  - 옮기려는 키가 대상 레디스 서버에 이미 존재하면 실패함

- `SELECT` : 레디스의 다중 데이터베이스 시스템 (0~15)에서 사용하는 데이터베이스를 변경
  - 다중 데이터베이스 사용보다는 여러 redis-server 프로세스의 사용 권장

- `AUTH` : 레디스에 연결할 클라이언트를 허가하는데 사용

- `SCRIPT KILL` : 쓰기 작업이 없는 루아 스크립트의 사용 중지 명령

- `SHUTDOWN` : 모든 클라이언트 종료 후 데이터를 최대한 저장한 후 레디스 서버 종료
  - `SAVE` : 저장 기능을 활성화하지 않더라도 `dump.rdb`영구 파일 생성
  - `NOSAVE` : 저장 기능이 활성화되어 있더라도 데이터를 디스크에 저장하지 않음
