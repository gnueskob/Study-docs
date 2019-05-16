# 레디스 확장과 분산

- 서버 하나로는 성능 향상의 한계가 존재하기 때문에 여러개의 서버로 확장, 분산하여 사용

- 성능 향상방법
  - 스케일 업(scale up) : 단일 머신에 CPU, 디스크 등을 추가해서 성능을 향상하는 방법
  - 스케일 아웃(scale out) : 적절한 성능의 머신을 추가해서 전체적인 성능을 향상하는 방법
    - 소프트웨어가 지원하는 경우만 가능
- 대량 데이터 처리 방법
  - 데이터 파티셔닝(Data Partitioning)
    - 대량의 데이터를 처리하기 위해 DBMS 안에서 분할
    - 한 대의 DBMS만 있어도 가능
    - `Scale up ---» 1 Machine ---» 1 DBMS ---» Data Partitioning`
  - 데이터 샤딩(Data Sharding)
    - 대량의 데이터를 처리하기 위해 여러 개의 DBMS에 분할
    - DBMS안에서 데이터를 나누는 것이 아니고 DBMS 밖에서 데이터를 나누는 방식
    - 샤드 수에 따라 여러 대의 DBMS를 설치해야 함
    - `Scale out ---» n Machines/VMs ---» n DBMSs ---» Data Sharding`
  - 두 가지 용어를 혼용해서 사용하는 경우도 존재
- 레디스의 스케일 아웃 방식의 성능 향상 기법 : 복제(`Replication`)와 샤딩(`Sharding`)

***

## 용어 정리

### `노드 (Node)`

- 하나의 레디스 서버를 의미

### `샤드 (Shard)`

- 두 개의 노드를 사용하여 데이터를 분할 저장 할 때의 각 노드

### `클러스터 (Cluster)`

- 여러 노드로 구성된 하나의 레디스 서버 집합
- 보통 마스터 노드와 여러개의 슬레이브 노드로 구성됨

***

## 복제

- 동일한 데이터를 다중의 노드에 중복하여 저장
- `Master-Slave` 복제의 개념 사용
- `Master` : 복제를 위한 데이터의 원본 역할
  - 기본적으로 마스터 노드에서 쓰기 연산을 수행
  - 슬레이브 노드의 정보가 필요 없음
- `Slave` : 마스터 노드에 데이터 복제 요청을 하고 데이터를 수신하여 동기화
  - 기본적으로 읽기 연산만 수행
  - 실시간으로 마스터 노드의 데이터를 복제
  - 슬레이브 노드 시작 시 마스터 노드에게 복제를 요청
  - 최초 복제 완료 이후 변경사항만 업데이트
  - 슬레이브 노드만이 마스터 노드의 위치 정보를 가지고 있음
- 슬레이브
- 읽기 성능의 증대를 위해 사용

### 단일 복제

- 마스터 노드 1개, 슬레이브 노드 1개
- 마스터 노드 변경 발생시 실시간으로 슬레이브 노드에 데이터 변경사항 기록
- 레디스 클러스터는 동기화를 위해 쓰기 연산 명령을 슬레이브 노드로 전달

```text
+--------+       +--------+
| Master | ───── | Slave1 |
+--------+       +--------+
```

### 다중 복제

- 단일 복제 구조에 슬레이브 노드를 추가
  - 새로운 슬레이브 노드에 마스터 노드 정보를 추가하여 인스턴스를 시작
  - 마스터 노드를 재시작 할 필요 없음
- 쓰기 연산에 비하여 읽기 연산이 많은 서비스에 적합한 구조
- 슬레이브 노드가 많이 연결될 수록 마스터 노드의 복제를 위한 리소스 자원이 많이 소모됨
  - 네트워크 리소스 비용이 매우 큼

```text
                 +--------+  (read)
     ┌────────── | Slave1 | ──────── Client
     │           +--------+
     │
+--------+       +--------+  (read)
| Master | ───── | Slave2 | ──────── Client
+--------+       +--------+
  │  │
  │  │           +--------+  (read)
  │  └────────── | Slave3 | ──────── Client
  │              +--------+
  │ (write)
  │
Client
```

### 계층형 복제

- 마스터 노드와 슬레이브 노드 1이 1차로 동기화
- 슬레이브 노드 1을 다른 슬레이브 노드들이 복제
- 기본적으로 슬레이브 노드 1은 읽기,쓰기 연산을 제외한 복제만 하도록 설정함 (리소스 부족)

```text
                                 +--------+  (read)
                     ┌────────── | Slave2 | ──────── Client
                     │           +--------+
                     │
+--------+       +--------+      +--------+  (read)
| Master | ───── | Slave1 | ──── | Slave3 | ──────── Client
+--------+       +--------+      +--------+
    │                │
    │                │           +--------+  (read)
    │                └────────── | Slave4 | ──────── Client
    │                            +--------+
    │ (write)
    │
 Client
```

***

## 샤딩

- 복제를 사용했을 경우보다 더 많은 데이터 저장 가능
- 쓰기 성능의 증대를 꾀할 수 있음
  - 각 서버가 존재하는 다중의 하드웨어에 쓰기 연산을 분산
- `수직 샤딩` : RDBMS에서의 테이블에 해당하는 정보를 노드별로 분할하여 저장
- `범위 지정 샤딩` : 키를 특정 범위 기준으로 분할하여 저장
  - ex) key 1~500: 노드 1 서버에 저장, key 501~1000: 노드 2 서버에 저장
- `해시 기반 샤딩` : 키를 해시 함수에 대입하여 결과값에 특정 연산을 가해 분할하여 저장
  - `일관된 해싱 (Consistent Hashing)`
  - ex) 샤드 번호 = md5('user:123') % 4

***

## 복제와 샤딩 혼합

- 레디스 클러스터는 복제와 샤딩을 혼합하여 구성할 수 있음

```text
┌────────────────Redis Cluster───────────────┐
│      shard 1                  shard 2      │
│  ┌─────────────┐          ┌─────────────┐  │
│  │ +---------+ │          │ +---------+ │  │
│  │ | 1, 2, 3 | │          │ | 4, 5, 6 | │  │
│  │ +---------+ │          │ +---------+ │  │
│  │ Master Node │          │ Master Node │  │
│  │             │          │             │  │
│  │ +---------+ │          │ +---------+ │  │
│  │ | 1, 2, 3 | │          │ | 4, 5, 6 | │  │
│  │ +---------+ │          │ +---------+ │  │
│  │  Slave Node │          │  Slave Node │  │
│  └─────────────┘          └─────────────┘  │
│                                            │
└────────────────────────────────────────────┘
```

***

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