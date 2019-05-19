# 레디스 클러스터와 센티넬

## 레디스 센티넬

- 마스터 인스턴스에서 문제 발생시 슬레이브 인스턴스 중 하나가 마스터로 승격해야 함
  - 센티넬이 있기 전에는 페일 오버 작업을 수동으로 했었으며 안정적이지 않았음
- 레디스 센티널은 마스터가 작동이 안 되면 슬레이브 중 하나를 마스터로 자동 승격시킴
  - 수동 설정 없이 자동으로 슬레이브가 마스터로 승격되는 분산 시스템
- 일반적인 아키텍쳐 - 레디스 서버마다 하나의 레디스 센티널 설치
  - 레디스 세티널은 레디스 서버와 분리된 프로세스
  - 레디스 서버와는 다른 포트를 염

```text
# 마스터 1개 - 슬레이브 2개 기준
# 센티널이 없는 기존 레디스 아키텍쳐

        +--------+
        | Master |
        +--------+
     ┌─────┘  └─────┐
     ↓              ↓
+--------+      +--------+
| Slave1 |      | Slave2 |
+--------+      +--------+

# 센티넬을 이용한 경우

                       +--------+
     ┌─────────────────| Master |─────────────────┐
     │                 +--------+                 │
     │                   ↑ ↑ ↑                    │
     │            ┌──────┘ │ └───────┐            │
     │            │     +------+     │            │
     │            │     | stnl |     │            │
     │            │     +------+     │            │
     │            │       ↑  ↑       │            │
     │            │  ┌────┘  └────┐  │            │
     ↓            ↓  ↓            ↓  ↓            ↓
+--------+      +------+        +------+      +--------+
| Slave1 | ←----| stnl | ←----→ | stnl |----→ | Slave2 |
+--------+      +------+        +------+      +--------+
     ↑              ↑              ↑              ↑
     └──────────────┼──────────────┘              │
                    └─────────────────────────────┘
```

- 레디스 센티널은 기존 레디스와 다른 인터페이스로 구현됨
- 센티널을 사용하기 위해서는 센티널을 지원하는 레디스 클라이언트를 따로 설치해야 함
- 클라이언트는 레디스 항상 인스턴스와 연결돼 있지만,  
  연결할 인스턴스를 찾기 위해서는 센티널에 질의해야 함
- `sentinel.conf`: 센티널 설정파일
  - 센티널을 지원하는 클라이언트를 받으면 위와같은 설정파일이 존재
  - 초기 설정 때 마스터 레디스 목록만 작성
  - 레디스 센티널을 시작하면 마스터에게 질의해 연결된 모든 슬레이브를 찾을 수 있음
  - 자동으로 센티널 설정이 재작성되는 경우
    - 센티널이 사용 가능한 모든 슬레이브를 찾을 때 또는 페일 오버가 발생할 때
- 모든 센티널 간의 통신은 `__sentinel__:hello`라는 Pub/Sub 채널을 통해 마스터에서 행해짐

***

## 기본 센티널 설정

- 센티널 설정은 이름 식별을 갖고 IP와 포트로 식별할 수 있는 마스터를 항상 모니터링
- 센티널 설정에 센티널 그룹의 이름을 명세할 수 있음
- 새로운 마스터가 선추뢰거나 새로운 센티널이나 슬레이브 인스턴스가 그룹에 참여할 경우  
  센티널 설정은 재작성됨

```text
# sentinel.conf
seninel monitor mymaster 127.0.0.1 6379 2
seninel down-after-milliseconds mymaster 30000
seninel failover-timeout mymaster 180000
seninel parallel-syncs mymaster 1
```

- 상세 설정
  - `monitor`
    - 이름 : mymaster
    - IP : 127.0.0.1
    - PORT : 6379
    - Quorum : 2
      - 쿼럼 : 마스터를 선출하기 전 동의 여부를 결정하는 인스턴스 집합
      - 새로운 마스터 선출 전 현재 마스터가 다운 상태임을 동의하는 센티널
  - `down-after-milliseconds`
    - 특정 센티널은 명세된 밀리초 동안 마스터에 도달하지 못할 경우
      - PING에 대한 응답을 받지 못하는 경우
    - 다른 센티널에게 마스터가 다운 됐음을 알림
  - `failover-timeout`
    - 짧은 시간내에 문제가 발생한 마스터의 페일오버를 피하기 위함
    - ex) R1: 마스터, R2, R3, R4: 슬레이브
      - 마스터에 문제가 발생해 슬레이브가 새로운 마스터를 선출해야 하는 상황
      - R2가 새로운 마스터가 되고 R1은 슬레이브 그룹으로 변경
      - 다시 R2에 문제가 발생하여 마스터를 선출해야 하는 상황
      - `failover-timeout`시간 초과전에 쿼럼의 투표가 일어나야 할 경우
      - R1은 마스터로 선출될 수 있는 노드가 되지 못함
  - `parallel-syncs`
    - 새로운 마스터와 연결하기 위해 동시에 재설정될 수 있는 슬레이브 개수
    - 이 프로세스가 진행되는 동안 슬레이브는 클라이언트에서 사용할 수 없는 상태

***

## 레디스 클러스터

- 여러 레디스 인스턴스에 데이터를 자동으로 샤딩할 수 있도록 설계됨
- 네트워크 파티션이 발생하더라도 어느 정도 가용성을 제공
- 센티널과 달리 실행 가능한 하나의 프로세스만 필요로 함
  - 그러나 레디스가 사용하는 포트는 2개
  - 숫자가 낮은 첫 번째 포트 : 클라이언트용
  - 숫자가 높은 두 번째 포트 : 노드 간의 통신을 위한 버스용
    - 문제 탐지, 페일오버, 리샤딩 같은 메시지를 교환하기 위해 사용됨
- 클러스터의 버스는 노드 간의 메시지를 교환할 때 바이너리 프로토콜을 사용
- 숫자가 낮은 포트에 10,000을 더해 두 번째 클러스터 버스용 포트를 할당
- 클러스터의 Topology는 `full mesh network`이며 TCP 연결 방식을 사용
- 클러스터 상태가 안정적이려면 최소 3개의 마스터 필요

```text
# 동작 중인 클러스터의 최소한의 설정
    +----------+          +----------+          +----------+
    | Master A |          | Master B |          | Master C |
    +----------+          +----------+          +----------+
   slot: 0 ~ 6000     slot: 6001 ~ 12000    slot: 12001 ~ 16383
```

- 마스터마다 최소 하나의 복제본을 두는 것을 권장
- 복제본이 하나도 없을 경우 마스터 노드가 작동이 안되면 해당 데이터를 잃게됨

```text
# 동작 중인 클러스터의 최소한의 설정
                                                    장 애
    +----------+          +----------+          +----------+
    | Master A |          | Master B |          | Master C |
    +----------+          +----------+          +----------+
   slot: 0 ~ 6000     slot: 6001 ~ 12000    slot: 12001 ~ 16383
```

- 마스터 노드 장애 시 모든 클러스터는 설정에 따라 사용 불가능으로 변하게 할 수도 있음
- 센티널과 달리 페일오버가 레디스 클러스터에서 발생한다면
  - 슬레이브가 마스터로 승격할 때까지 문제된 마스터로 할당된 슬롯의 키는 사용 불가능
    - (예시 기준) slot: 12001 ~ 16383 사용 불가
  - 슬레이브 승격이 즉각적이지 않기 때문에 페일오버시 데이터를 사용하지 못할 수 있음
- 레디스가 클러스터 모드에서 동작 중이면 인터페이스가 약간 바뀜
  - 때문에 클라이언트가 더 똑똑해야함
  - `-c` 옵션을 통해 클러스터 모드로 동작하게 함 (기본은 싱글 인스턴스 모드)

```bash
redis-cli -c -h localhost -p 6379
```

***

## 해시 슬롯

- 클러스터가 데이터를 샤딩하기 위해 사용하는 파티셔닝 방법은 해시
  - 하지만 기존 해시 파티셔닝과는 달리 16384 슬롯 고정값을 사용
  - 16384 슬롯 각각을 해시 슬롯이라 하며 클러스터의 각 마스터는 슬롯 일부를 소유
- 키를 저웃로 변환하기 위해 `CRC-16`해시 함수 사용, 16384로 모듈로 연산

```text
HASH_SLOT = CRC16(key) mod 16384
```

- 마스터는 슬롯을 할당받지 못하면 데이터를 저장할 수 없음
  - 해당 마스터에 연결된 클라이언트는 질의를 이용해 다른 마스터로 방향을 바꿈
- 마스터는 최소 하나의 슬롯을 가져야 함
- 모든 마스터에 할당할 수 있는 전체 슬롯 개수는 16384가 되어야 함
- 마스터에 대한 슬롯의 자동 재분포는 없음
  - 각 마스터에 x개의 슬롯을 수동으로 할당해야 함

***

## 해시 태그

- 다중 키 작업을 진행하려면 동일 노드에 저장될 모든 키가 필요
- 해시 태그는 클러스터에서 다중 키를 사용할 수 있는 유일한 방법
- 해시 태그는 해시 함수를 적용해 동일한 해시 슬롯에 여러 개의 키 이름을 저장할 수 있음

```redis
# {user123} 이라는 해시 태그를 사용하므로 모든 키가 동일한 슬롯에 저장됨
SADD {user123}:friends:usa "John" "Bob"
SADD {user123}:friends:brazil "Max" "Hugo"
SUNION {user123}:all_friends {user123}:friends:usa {user123}:friends:brazil
```

***

## 기본 클러스터의 생성

- 클러스터를 쉽게 관리하기 위해 `redis-trib` 유틸리티를 사용
- 레디스 프로젝트의 `utils/create-cluster` 디렉토리에 `create-cluster` 스크립트 존재
- 해당 쉘 스크립트로 해시 슬롯 분포 방법을 결정하여 클러스터 생성 가능

## 노드 검색과 리다이렉트

- 일부 노드는 특정 질의를 실행하는 데 필요한 슬롯이 없을 수도 있음
- 클라이언트는 질의에서 쓰이는 모든 키를 가진 노드를 찾는 일에 책임을 져야 함
- 해당 질의를 실행할 수 있는 노드로의 연결로 넘겨줘야 함

```bash
$ redis-cli -c -h localhost -p 30001
localhost:30001> SET hello world
OK
localhost:30001> GET hello
-> Redirected to slot [12182] located at 127.0.0.1:30003
OK
```

## 설정

- 클러스터 모드에서 레디스를 실행하려면 새로운 지시자를 추가로 명세해야 함
  - 지시자 명세하지 않을 경우 싱글 인스턴스로 실행됨

```text
# redis.conf
cluster-enabled yes
cluster-config-file cluster.conf
cluster-node-timeout 2000
cluster-slave-validity-factor 10
cluster-migration-barrier 1
cluster-require-full-coverage yes
```

### 지시자 상세 설명

- `cluster-enabled`
  - 레디스가 클러스터 모드로 실행되는지 여부 결정
  - 기본값 `no`
- `cluster-config-file`
  - 클러스터에서 발생한 변경을 저장할 수 있는 설정 파일의 경로 필요
  - 클러스터 내의 모든 노드와 노드의 상태, 저장 변수와 같은 정보를 해당 파일로 생성
  - 클러스터의 변경이 있을 때마다 해당 파일에 로그가 저장됨
- `cluster-node-timeout`
  - 노드를 장애로 판단하지 않고 노드가 사용 불가능한 상태로 있을 수 있는 최대 시간
  - 타임아웃이 발생한 노드가 마스터라면 페일오버가 발생해 슬레이브 중 하나가 승격
  - 타임아웃이 발생한 노드가 슬레이브라면 해당 노드는 더 이상 질의를 받지 못함
- `cluster-slave-validity-factor`
  - 네트워크 장애로 불필요한 페일오버 과정이 생길 수 있는 문제를 최소화 시켜주는 지시자
  - 네트워크에 문제가 생겨 마스터 노드가 특정시간 동안 다른 노드와 통신이 불가능할 때
    - 특정 시간 : `cluster-slave-validity-factor` * `cluster-node-timeout`
    - 이 특정 시간 내에는 슬레이브의 마스터 승격이 이뤄지지 않음
  - 이 지시자 값을 0으로 설정하면 어떤 페일 오버도 막을 수 없음
    - 네트워크 연결 문제가 잠깐이라도 발생하면 바로 페일오버를 수행
- `cluster-migration-barrier`
  - 마스터에 연결되어야 할 최소 슬레이브 개수
  - 슬레이브개수가 모자란 마스터는 다른 마스터로부터 여분의 슬레이브를 빌려야 함
    - 만약 다른 마스터에게 여분의 슬레이브가 없다면 변경은 일어나지 않음
- `cluster-require-full-coverage`
  - 만약 슬레이브가 없는 상태에서 마스터 노드의 장애가 나타난 경우 두 가지 방안 존재
    - `yes`: 전체 클러스터를 사용 불가능하게 만들기
      - 클러스터가 모든 해시 슬롯이 실행 중인 인스턴스로 할당된 경우에만 작동
    - `no`: 클러스터 사용 가능, 장애가 발생한 마스터로 전달되는 키는 에러처리

***

## 클러스터 관리

### 클러스터 생성

- 3개의 마스터를 가진 클러스터를 생성

```bash
$ redis-server \
--port 5000 \
--cluster-enabled yes \
--cluster-config-file nodes-5000.conf \
--cluster-node-timeout 2000 \
--cluster-slave-validity-factor 10 \
--cluster-migration-barrier 1 \
--cluster-require-full-coverage yes \
--dbfilename dump-5000.rdb \
--daemonize yes

$ redis-server \
--port 5001 \
--cluster-enabled yes \
--cluster-config-file nodes-5001.conf \
--cluster-node-timeout 2000 \
--cluster-slave-validity-factor 10 \
--cluster-migration-barrier 1 \
--cluster-require-full-coverage yes \
--dbfilename dump-5001.rdb \
--daemonize yes

$ redis-server \
--port 5002 \
--cluster-enabled yes \
--cluster-config-file nodes-5002.conf \
--cluster-node-timeout 2000 \
--cluster-slave-validity-factor 10 \
--cluster-migration-barrier 1 \
--cluster-require-full-coverage yes \
--dbfilename dump-5002.rdb \
--daemonize yes
```

- 아직은 클러스터를 실행할 준비가 되지 않은 상태
- `CLUSTER INFO`로 클러스터 상태 확인 가능

```bash
$ redis-cli -c -p 5000
127.0.0.1:5000> CLUSTER INFO
cluster_state:fail
cluster_slots_assigned:0
cluster_slots_ok:0
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:1
cluster_size:0
cluster_current_epoch:0
cluster_my_epoch:0
cluster_stats_messages_sent:0
cluster_stats_messages_received:0
127.0.0.1:5000> SET foo bar
(error) CLUSTERDOWN The cluster is down
```

- 현재 클러스터 상태는 하나의 노드만 알고, 어떤 노드에도 슬롯이 할당되어있지 않음
- 클러스터의 상태가 실패면 어떠한 질의도 처리 불가능
- 16384개의 해시 슬롯을 인스턴스로 분배해야 함

```bash
redis-cli -c -p 5000 CLUSTER ADDSLOTS {0..5460}
redis-cli -c -p 5001 CLUSTER ADDSLOTS {5461..10922}
redis-cli -c -p 5002 CLUSTER ADDSLOTS {10923..16383}
```

- `CLUSTER ADDSLOTS`명령은 노드가 소유할 해시 슬롯 값을 알려줌
  - 해시 슬롯이 이미 할당된 상태라면 명령은 실패
- 이 시점에서도 클러스터는 아직 준비되지 않음
  - 클러스터 노드는 서로에 대해 알지 못하기 때문
- 클러스터에서 특정 시점에 클러스터 상태를 표시하는 숫자인 에포크(`epoch`) 설정 존재
  - 해당 값은 새로운 이벤트가 발생하거나 노드가 다음에 발생할 것을 동의해야 할 때 사용
    - 다음에 발생할 것 - 페일오버 또는 해시 슬롯의 리샤딩
  - 클러스터 초기 생성시 각 마스터 에포크 설정은 0
  - 에포크 설정을 변경해야 클러스터를 시작할 수 있음
  - 클러스터가 시작되고 난 후에는 자동으로 에포크 설정이 변경됨

```bash
redis-cli -c -p 5000 CLUSTER SET-CONFIG-EPOCH 1
redis-cli -c -p 5001 CLUSTER SET-CONFIG-EPOCH 2
redis-cli -c -p 5002 CLUSTER SET-CONFIG-EPOCH 3
```

- 충돌이 존재하는 경우 (ex., 다른 노드가 같은 해시슬롯을 요구하는 경우)
  - 높은 에포크 설정이 우선권을 가짐
- 또한, 노드가 서로를 인식할 수 있도록 `CLUSTER MEET`명령 사용

```bash
redis-cli -c -p 5000 CLUSTER MEET 127.0.0.1 5001
redis-cli -c -p 5000 CLUSTER MEET 127.0.0.1 5002
```

- 모든 노드가 서로의 존재를 알리기 위해 각 노드마다 커맨드를 실행할 필요는 없음
- 각 노드를 연결 할때는 해당 노드에 연결된 노드도 자동으로 알게됨
  - 레디스 클러스터의 gossip 프로토콜을 사용해 모든 노드가 연결됨

```bash
$ redis-cli -c -p 5000
127.0.0.1:5000> CLUSTER INFO
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:3
cluster_size:3
cluster_current_epoch:3
cluster_my_epoch:1
cluster_stats_messages_sent:164
cluster_stats_messages_received:144
127.0.0.1:5000> SET foo bar
OK
```

### 슬레이브/복제본 추가

- 다음 방법을 통해 새로운 슬레이브/복제본을 클러스터에 추가할 수 있음

1. 새로운 레디스 인스턴스를 클러스터 모드에 생성

    ```bash
    $ redis-server \
    --port 5003 \
    --cluster-enabled yes \
    --cluster-config-file nodes-5003.conf \
    --cluster-node-timeout 2000 \
    --cluster-slave-validity-factor 10 \
    --cluster-migration-barrier 1 \
    --cluster-require-full-coverage yes \
    --dbfilename dump-5003.rdb \
    --daemonize yes
    ```

2. `CLUSTER MEET`명령을 통해 새로운 레디스를 현재의 클러스터에 소개

    ```bash
    redis-cli -c -p 5003 CLUSTER MEET 127.0.0.1 5000
    ```

3. `CLUSTER NODES`명령을 통해 복제될 마스터의 노드 ID 얻기

    ```bash
    $ redis-cli -c -p 5003 CLUSTER NODES
    08cbbb4c05ec977af9c4925834a71971bbea3477 127.0.0.1:5003 myself,master - 0 0 0 connected
    b5354de29d7ec02e64580658d3f59422cfeda916 127.0.0.1:5002 matser - 0 1432276450590 3 connected 10923-16383
    a1c2536d48456153bad84f485da324c586ec54df 127.0.0.1:5001 master - 0 1432276449782 2 connected 5461-10922
    a564cd1c2d3c45d6a8e68dd429124b456f8645ee 127.0.0.1:5000 master - 0 1432276449782 1 connected 0-5460
    # <node_id> <ip:port> <flags> <master> <ping-sent> <pong-recv> <config-epoch> <link-state> <slots>
    ```

    - `CLUSTER NODES`명령은 클러스터에 속한 모든 노드의 속성을 목록으로 출력

4. `CLUSTER REPLICATE`명령을 통해 주어진 노드 복제하기

    ```bash
    # port 5000 노드를 복제
    redis-cli -c -p 5003 CLUSTER REPLICATE a564cd1c2d3c45d6a8e68dd429124b456f8645ee
    ```

    ```bash
    $ redis-cli -c -p 5003 CLUSTER NODES
    08cbbb4c05ec977af9c4925834a71971bbea3477 127.0.0.1:5003 myself,slave a564cd1c2d3c45d6a8e68dd429124b456f8645ee 0 0 0 connected
    b5354de29d7ec02e64580658d3f59422cfeda916 127.0.0.1:5002 matser - 0 1432276450590 3 connected 10923-16383
    a1c2536d48456153bad84f485da324c586ec54df 127.0.0.1:5001 master - 0 1432276449782 2 connected 5461-10922
    a564cd1c2d3c45d6a8e68dd429124b456f8645ee 127.0.0.1:5000 master - 0 1432276449782 1 connected 0-5460
    ```

    - 복제 명령 후에 다시 확인한 결과 5003 포트 레디스 노드가 `slave`로 변한 것을 확인

### 슬레이브 노드를 이용해 읽기 확장

- 클러스터에서 읽기를 확장하기 위해 슬레이브에 연결해서 `READONLY`명령 사용
  - 해당 슬레이브를 읽기 전용 모드로 변경 가능
- `READWRITE`명령을 통해 읽기 전용 모드 종료 가능
- 읽기 전용 모드가 사용되지 않으면, 모든 질의는 마스터 노드로 전달됨

### 노드 추가

- 새로운 노드가 추가되면 해시 슬롯이 전혀 없는 마스터로 간주됨
  - 때문에 해당 노드에 접속하고 질의를 실행하면 질의가 다른 노드로 전달됨
- 클러스터에서 리샤딩(resharding)을 통해 해시 슬롯을 재 분배
  - 하나 또는 여러 해시 슬롯을 원본 노드에서 목적 노드로 옮기고 키도 함께 이전

1. 클러스터 모드에 새로운 레디스 인스턴스 생성

    ```bash
    $ redis-server \
    --port 6000 \
    --cluster-enabled yes \
    --cluster-config-file nodes-6000.conf \
    --cluster-node-timeout 2000 \
    --cluster-slave-validity-factor 10 \
    --cluster-migration-barrier 1 \
    --cluster-require-full-coverage yes \
    --dbfilename dump-6000.rdb \
    --daemonize yes
    ```

2. 클러스터에 노드 소개

    ```bash
    redis-cli -c -p 6000 CLUSTER MEET 127.0.0.1 5000
    ```

3. 새로운 노드와 목적노드의 노드 ID 검색

    - `CLUSTER NODES`명령을 통해 ID 확인
    - 리샤딩을 실행하기 전에, 해시 슬롯을 채울 수 있는 키를 저장

    ```redis
    127.0.0.1:6000> SET book "redis essentials"
    -> Redirected to slot [1337] located at 127.0.0.1:5000
    ```

4. 해시 슬롯을 리샤딩하고 기존 키를 옮김

    - 클러스터는 한 번에 하나의 해시 슬롯만 리샤딩함
    - 많은 해시 슬롯을 리샤딩해야 하면 다음 과정을 각 해시 슬롯에 대해 한 번씩 실행
    - 리 샤딩 과정
      1. 원본 마스터 노드에서 해시 슬롯을 export
      2. 대상 마스터 노드로 해시 슬롯을 import
      3. 원본 노드에 해시 슬롯 존재시 해당 해시 슬롯의 모든 키를 대상 노드로 옮김
      4. 해시 슬롯이 새로운 대상 노드로 이동했음을 모든 노드에게 알림
    - `CLUSTER SETSLOT <hash-slot> [sub-command] <source-id>`
      - `IMPORTING` 하위 명령
        - 해시 슬롯의 상태를 importing으로 변경
        - 해시 슬롯을 받는 노드에서 실행
        - 현재 슬롯을 소유한 노드 ID도 전달해야 함
      - `MIGRATING` 하위 명령
        - 해시 슬롯의 상태를 migrating으로 변경
        - `IMPORTING`의 반대
        - 해시 슬롯을 소유한 노드에서 실행
        - 새로 슬롯을 소유하는 노드 ID도 전잘
      - `NODE` 하위 명령
        - 해시 슬롯을 노드에 연관시킴
        - 원본 노드와 목적 노드에서 실행
          - 해시 슬롯 이전동안 잘못된 노드로 키를 전달하지 않도록  
            모든 마스터에서 실행하는 것을 권장
        - 목적 노드에서 실행 후 importing상태가 정리되고 에포크 설정이 변경됨
        - 원본 노드에서 실행 후 더 이상 슬롯에 키가 없으면 migrating이 정리됨

      ```bash
      # 1337 해시 슬롯을 5000 포트 원본 노드에서 6000 포트 목적 노드로 이전
      $ redis-cli -c -p 6000 CLUSTER SETSLOT 1337 IMPORTING a564cd1c2d3c45d6a8e68dd429124b456f8645ee
      $ redis-cli -c -p 5000 CLUSTER SETSLOT 1337 MIGRARTING f489e546d4f55f4a65da45123b159a234da56c45
      ```

    - `CLUSTER COUNTKEYSINSLOT <slot>`: 주어진 슬롯에 있는 키 개수 반환
    - `CLUSTER GETKEYSINSLOT <slot> <amount>`: 슬롯에 있는 키 이름을 개수만큼 반환
    - `MIGRATE <host> <port> <key> <db> <timeout>`: 키를 다른 노드로 이전

    ```bash
    $ redis-cli -c -p 5000
    127.0.0.1:5000> CLUSTER COUNTKEYSINSLOT 1337
    (integer) 1
    127.0.0.1:5000> CLUSTER GETKEYSINSLOT 1337 1
    1) "book"
    127.0.0.1:5000> MIGRATE 127.0.0.1 6000 book 0 2000
    OK
    ```

    - 마지막으로 모든 노드는 1337 해시 슬롯의 새로운 소유자 정보를 전달받음

    ```bash
    $ redis-cli -c -p 5000 CLUSTER SETSLOT 1337 NODE f489e546d4f55f4a65da45123b159a234da56c45
    $ redis-cli -c -p 5001 CLUSTER SETSLOT 1337 NODE f489e546d4f55f4a65da45123b159a234da56c45
    $ redis-cli -c -p 5002 CLUSTER SETSLOT 1337 NODE f489e546d4f55f4a65da45123b159a234da56c45
    $ redis-cli -c -p 6000 CLUSTER SETSLOT 1337 NODE f489e546d4f55f4a65da45123b159a234da56c45

    # CLUSTER NODES로 상태 확인
    $ redis-cli -c -p 6000 CLUSTER NODES
    08cbbb4c05ec977af9c4925834a71971bbea3477 127.0.0.1:5003 slave a564cd1c2d3c45d6a8e68dd429124b456f8645ee 0 1432276457644 1 connected
    b5354de29d7ec02e64580658d3f59422cfeda916 127.0.0.1:5002 matser - 0 1432276457041 3 connected 10923-16383
    a1c2536d48456153bad84f485da324c586ec54df 127.0.0.1:5001 master - 0 1432276457141 2 connected 5461-10922
    a564cd1c2d3c45d6a8e68dd429124b456f8645ee 127.0.0.1:5000 master - 0 1432276457644 1 connected 0-1336 1338-5460
    f489e546d4f55f4a65da45123b159a234da56c45 127.0.0.1:6000 myself,master - 0 0 4 connected 1337
    ```

### 노드 삭제

- 노드를 삭제하려면 삭제할 노드에 할당된 모든 해시 슬롯을 다른 노드로 리샤딩해야함
- 또한 모든 노드는 알고있는 노드 목록에서 삭제할 노드를 지워야 함
- `CLUSTER FORGET <node-id>`명령
  - 모든 해시 슬롯이 재분배 된 후에 클러스터에서 노드를 삭제해야 함
  - 해당 명령은 60초 이내로 삭제 노드를 제외한 모든 마스터노드에서 실행되어야 함
  - 명령을 실행하자마자 삭제될 노드를 금지 목록에 추가함
    - 노드끼리 메시지를 교환할 때 삭제된 노드가 다시 추가되는 것을 방지하기 위함
  - 금지 목록의 만료시간은 60초

### redis-trib 툴을 이용한 클러스터 관리

- 인터페이스는 매우 직관적이며 일부 커맨드가 존재
- `./src/redis-trib.rb`로 실행 가능
- 확인, 수정, 리샤딩, 노드 삭제, 타임아웃 설정을 위해 클러스터 노드의 장비와 포트 명세필요

```bash
# 클러스터 모드에서 실행할 수 있는 8개의 인스턴스를 생성하는 커맨드
# 아직 인스턴스는 클러스터에 포함되지 않음
$ for port in 5000 5001 5002 5003 5004 5005 5006 5007; do
  redis-server \
    --port ${port} \
    --cluster-enabled yes \
    --cluster-config-file nodes-${port}.conf \
    --cluster-node-timeout 2000 \
    --cluster-slave-validity-factor 10 \
    --cluster-migration-barrier 1 \
    --cluster-require-full-coverage yes \
    --dbfilename dump-${port}.rdb \
    --daemonize yes
done

# 3개의 마스터 노드와 각 마스터 노드마다 1개의 슬레이브를 연결하는 클러스터 생성
# 해시 슬롯이 균등하게 배포됨
$ ./src/redis-trib.rb create --replicas 1 \
  127.0.0.1:5000 \
  127.0.0.1:5001 \
  127.0.0.1:5002 \
  127.0.0.1:5003 \
  127.0.0.1:5004 \
  127.0.0.1:5005

# 클러스터에 새로운 마스터 노드 추가
$ ./src/redis-trib.rb add-node 127.0.0.1:5006 127.0.0.1:5000

# 10개의 슬롯을 한 노드에서 다른 노드로 리샤딩
# 5000 포트와 5006포트의 마스터 노드 ID를 찾기위해 CLUSTER NODES 실행
$ ./src/redis-trib.rb reshard --from SOURCE-NODE-ID --to DESTINATION-NODE-ID --slots 10 --yes 127.0.0.1:5000

# 새로운 슬레이브를 클러스터에 추가
# 최소 개수를 가진 슬레이브를 포함하는 새로운 마스터를 자동으로 선택
$ ./src/redis-trib.rb add-node --slave 127.0.0.1:5007 127.0.0.1:5000
```
