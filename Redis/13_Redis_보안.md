# 보안

## 기본적인 보안

- 레디스는 평문 패스워드를 기반으로 하는 기본 보안 메커니즘만을 제공
- 접근 제어목록도 없고 퍼미션 레벨 단위로 사용자를 구분 설정할 수도 없음
- `requirepass`기능
  - 인증 기능을 활성화 할 수 있음
  - 레디스는 메모리 기반처리로 매우 빠르기 때문에 brute-force위험도도 높음
  - 따라서 `requirepass` 설정을 최소 64자리 복잡한 패스워드로 명세하기를 권장
  - `requirepass`를 활성화하면 레디스는 인증없는 클라이언트를 모두 거부함
  - `redis.conf`에 다음의 코드 추가

  ```text
  requirepass a7!asd$7asd@askdjklaskdl...
  ```

  ```bash
  # conf 설정 후 레디스 서버 재시작
  redis-server .../path/redis.conf
  ```

  - 레디스 클라이언트에서는 `AUTH` 명령으로 인증

  ```redis
  127.0.0.1:6379> SET hello world
  (error) NOAUTH Authentication required.
  127.0.0.1:6379> AUTH a7!asd$7asd@askdjklaskdl...
  OK
  127.0.0.1:6379> SET hello world
  OK
  ```

***

## 중요 커맨드 이름 변경

- 레디스에서는 사용이 위험한 명령들의 이름을 바꾸거나 금지시켜야 함

```test
# renamed-redis.conf
rename-command FLUSHDB e0912asad9asd83asfaskld90
rename-command FLUSHALL a82asdj9m90vkoqw9812dasod
rename-command CONFIG ""
rename-command KETS ""
rename-command DEBUG ""
rename-command SAVE ""
...
```

```test
# redis.conf
...
include .../path/renamed-redis.conf
```

- 바뀐 명령 이름 체계 설정을 다른 파일로 분할하고 기존 레디스 설정파일에 추가

```redis
127.0.0.1:6379> SAVE
(error) ERR unknown command 'SAVE'
127.0.0.1:6379> FLUSHDB
(error) ERR unknown command 'FLUSHDB'
127.0.0.1:6379> e0912asad9asd83asfaskld90
OK
```

***

## 네트워크 보안

- 알 수 없는 클라이언트의 접속을 막기 위해 방화벽 규칙 사용
- 공개된 클라우드에서 네트워크 인터페이스로 바로 접속하지 못하게하고 루프백으로 레디스 사용
- 공용 인터넷 대신 가상 사설 클라우드에서 레디스 사용
- 클라이언트와 서버 간의 통신 암호화 (SSL, stunnel)