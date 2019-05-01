# 레디스 다루기

- `redis-server`
  - 실제 레디스의 저장소
  - 클러스터 모드 또는 독립 실행형(`standalone`) 모드로 실행 가능
- `redis-cli`
  - 모든 레디스 커맨드를 실행할 수 있는 CLI
- 레디스는 기본적으로 `6379`포트를 바인드, 독립 실행형 모드로 작동
- [모든 레디스 명령어](https://redis.io/commands)

***

## 싱글 스레드 (`single thread`)

- 레디스는 항상 한 번에 하나의 커맨드를 실행하는 싱글 스레드기반으로 동작
- 레디스는 `atomic` 커맨드를 제공
  - `atomic`이란 데이터의 읽기, 갱신, 쓰기 작업이 한 번에 이뤄지는 것
- 여러 개의 클라이언트가 동시에 명령을 실행해도 `race condition`이 발생하지 않음

***

## 기본 명령어

- `SET [key] [value]`, `GET [key]`
  - SET 명령으로 key 값에 value를 저장할 수 있음
  - GET 명령으로 레디스 서버에 저장된 value를 key값으로 가져올 수 있음

```redis
127.0.0.1:6379> set tempkey 1234
OK

127.0.0.1:6379> get tempkey
"1234"
```

- `HELP [command]`
  - HELP 커맨드로 레디스의 각종 명령어 문법 확인가능

```redis
127.0.0.1:6379> help set

  SET key value [EX seconds] [PX milliseconds] [NX|XX]
  summary: Set the string value of a key
  since: 1.0.0
  group: string
```

- `KEYS [pattern]`
  - 저장소에 저장된 키중 패턴과 일치하는 모든 키를 리턴
  - 레디스의 키 이름에는 별다른 제한이 없음 (바이트 배열도 키로 사용가능)
  - 관례상 키 중간에 콜론(`:`)을 붙여 구분자로 사용함

```redis
127.0.0.1:6379> KEYS t*
1) "tempkey"
```

***

## 데이터 타입

- 레디스 데이터 타입의 작동 방법을 이해해야 설계와 자원 사용이 쉬움
- 저장된 데이터 타입에 따라서 처리할 수 있는 명령이 달라질 수 있음

***

## 문자열

- 문자열은 많은 커맨드를 가지며 여러 목적으로 사용됨
- 레디스에서 가장 다양한 데이터 타입
- 정수(`integer`), 부동소수점(`float`), 텍스트 문자열, 비트맵 값을 기반으로  
  연관 커맨드를 사용함으로 동작
- 텍스트(`XML`, `JSON`, `HTML`, `raw text`), 정수, 부동소수점, 바이너리 데이터(`video`, `audio` 파일) 등  
  어떤 종류의 데이터라도 저장할 수 있음
- 문자열 값은 `512MB`를 초과할 수 없음

## 문자열 명령

- 아래 설명하는 명령어들은 `atomic` 명령

- `SET` (앞서 언급함)
  - value값으로 숫자를 입력해도 문자열로 취급
  - 또한, 중복된 키에 대한 입력을 아무런 오류 없이 실행함

| 명령    | `SET [key] [value]` |
| :---- | :------------------ |
| 지원버전  | >= 1.0.0            |
| 시간복잡도 | O(1)                |
| 응답    | <상태응답>, OK          |

```redis
127.0.0.1:6379> set tempkey 1111
OK

127.0.0.1:6379> get tempkey
"1111"

127.0.0.1:6379> set tempkey 1234
OK

127.0.0.1:6379> get tempkey
"1234"
```

- `MSET`, `MGET`
  - `SET`, `GET` 명령을 다중 키로 사용 가능
  - `MSET [key1] [value1] ([key2] [value2], ...)`
  - `MGET [key1] ([key2], [key3], ...)`

```redis
127.0.0.1:6379> MSET first 1 second 2
OK
127.0.0.1:6379> MGET first second
1) "1"
2) "2"
```

- `EXPIRE`
  - 주어진 키에 대한 만료 시간(초 단위)를 추가
  - 만료 시간이 지나면 자동으로 레디스에서 삭제됨

| 명령    | `EXPIRE [key] [seconds]` |
| :---- | :----------------------- |
| 지원버전  | >= 1.0.0                 |
| 시간복잡도 | O(1)                     |
| 응답    | 숫자응답                     |
| 0     | 키가 존재하지 않거나 설정 불가능       |
| 1     | 설정 완료                    |

- `TTL(Time To Live)`
  - 주어진 키의 생존 시간(초 단위)을 알려줌

| 명령    | `TTL [key]`            |
| :---- | :--------------------- |
| 지원버전  | >= 1.0.0               |
| 시간복잡도 | O(1)                   |
| 응답    | 숫자응답                   |
| 양의 정수 | 주어진 키의 생존 시간초          |
| -1    | 키가 존재하지만 만료시간이 설정되지 않음 |
| -2    | 키가 만료되었거나 존재하지 않음      |

```redis
127.0.0.1:6379> expire asd
(error) ERR wrong number of arguments for 'expire' command

127.0.0.1:6379> expire first 10
(integer) 1
127.0.0.1:6379> ttl first
(integer) 6
127.0.0.1:6379> get first
"1"
127.0.0.1:6379> ttl first
(integer) -2
127.0.0.1:6379> get first
(nil)
```

- `APPEND`
  - 주어진 키가 존재하면 입력된 value를 이미 저장된 값 뒤에 추가
  - 키가 존재하지 않으면 `SET`명령과 동일

| 명령    | `APPEND [key] [value]`          |
| :---- | :------------------------------ |
| 지원버전  | >= 2.0.0                        |
| 시간복잡도 | O(1)                            |
| 응답    | <숫자응답>, 추가된 문자열을 포함한 전체 문자열의 길이 |

```redis
127.0.0.1:6379> append tempkey 99
(integer) 6

127.0.0.1:6379> get tempkey
"123499"
```

- `INCR`
  - 저장된 value값을 1씩 증가시킴
  - 저장된 value값이 숫자형식일 때만 사용 가능

| 명령    | `INCR [key]`              |
| :---- | :------------------------ |
| 지원버전  | >= 1.0.0                  |
| 시간복잡도 | O(1)                      |
| 응답    | <숫자응답>, 명령이 실행된 후 value 값 |

- `INCRBY`
  - key에 저장된 value값을 원하는 만큼 증가시킴
  - 저장된 value값이 숫자형식일 때만 사용 가능

| 명령    | `INCRBY [key] [value]`    |
| :---- | :------------------------ |
| 지원버전  | >= 1.0.0                  |
| 시간복잡도 | O(1)                      |
| 응답    | <숫자응답>, 명령이 실행된 후 value 값 |

```redis
127.0.0.1:6379> get login:counter
"asd"
127.0.0.1:6379> incr login:counter
(error) ERR value is not an integer or out of range

127.0.0.1:6379> set login:counter 0
OK
127.0.0.1:6379> incr login:counter
(integer) 1
127.0.0.1:6379> incr login:counter
(integer) 2
127.0.0.1:6379> get login:counter
"2"
127.0.0.1:6379> incrby login:counter 5
(integer) 7
```

- `DECR`
  - 저장된 value값을 1씩 감소시킴
  - 저장된 value값이 숫자형식일 때만 사용 가능

| 명령    | `DECR [key]`              |
| :---- | :------------------------ |
| 지원버전  | >= 1.0.0                  |
| 시간복잡도 | O(1)                      |
| 응답    | <숫자응답>, 명령이 실행된 후 value 값 |

- `DECRBY`
  - 저장된 value값을 1씩 감소시킴
  - 저장된 value값이 숫자형식일 때만 사용 가능

| 명령    | `DECRBY [key] [value]`    |
| :---- | :------------------------ |
| 지원버전  | >= 1.0.0                  |
| 시간복잡도 | O(1)                      |
| 응답    | <숫자응답>, 명령이 실행된 후 value 값 |

```redis
127.0.0.1:6379> set login:counter "10a"
OK
127.0.0.1:6379> decr login:counter
(error) ERR value is not an integer or out of range

127.0.0.1:6379> set login:counter 10
OK
127.0.0.1:6379> decr login:counter
(integer) 9
127.0.0.1:6379> decr login:counter
(integer) 8
127.0.0.1:6379> get login:counter
"8"
127.0.0.1:6379> decrby login:counter 6
(integer) 2
```

- `INCRBYFLOAT`, `DECRBYFLOAT`
  - 부동소수점을 받아 키 값을 증감시킴
  - 저장된 value값이 숫자형식일 때만 사용 가능

| 명령    | `INCRBYFLOAT/DECRBYFLOAT [key] [value]` |
| :---- | :-------------------------------------- |
| 지원버전  | >= 1.0.0                                |
| 시간복잡도 | O(1)                                    |
| 응답    | <숫자응답>, 명령이 실행된 후 value 값               |

```redis
127.0.0.1:6379> set login:counter 10
OK
127.0.0.1:6379> incrbyfloat login:counter -10.001
"-0.000999999999999"
```

- 숫자 증감 명령에 대한 value값은 양수, 음수 모두 사용가능

***

## 리스트

- 레디스에서 지원하는 리스트 데이터 자료구조
- 논리적으로 링크드 리스트로 구현됨
  - 데이터 추가, 삭제 : `O(1)` 시간 복잡도
  - 데이터 접근 : `O(N)` 시간 복잡도
    - 때문에, 큐 & 스택 형식으로 많이 이용
  - 입력 순서의 유지
- 리스트는 최대 `2^32 - 1`개의 원소를 가질 수 있음
- 리스트의 인덱스는 `0`부터 시작
- 리스트의 값은 `GET`명령으로 가져올 수 없음

## 리스트 명령

- 리스트 커맨드는 `atomic` 특성을 가짐
  - 병렬 시스템이 큐(레디스 리스트)에서 중복된 원소를 얻는 것을 방지
- 블로킹 커맨드가 존재
  - 클라이언트가 비어있는 리스트에 블로킹 커맨드를 실행하면  
    해당 리스트에 원소가 추가될 때까지 기다려야함

- `LPUSH / RPUSH`
  - 지정된 리스트의 맨 앞쪽 / 맨 뒷쪽에 value를 저장

| 명령    | `LPUSH / RPUSH [key] [value1] ([value2], ...)` |
| :---- | :--------------------------------------------- |
| 지원버전  | >= 1.0.0                                       |
| 시간복잡도 | O(1)                                           |
| 응답    | <숫자응답>, 명령이 수행된 후 원소의 수                        |

- `LRANGE`
  - 지정된 리스트의 시작 ~ 종료 인덱스 범위 원소 조회
  - 종료 인덱스를 `-1` or `마지막 인덱스 이상의 값`으로 할 경우 마지막 인덱스까지 조회

| 명령    | `LRANGE [key] [start_idx] [end_idx]`   |
| :---- | :------------------------------------- |
| 지원버전  | >= 1.0.0                               |
| 시간복잡도 | O(S+N) (S : 시작 인덱스, N : 범위에 속하는 요소 개수) |
| 응답    | <멀티 벌크 응답>, 해당 범위의 원소들                 |

```redis
127.0.0.1:6379> lpush list 1st 2nd 3rd
(integer) 3
127.0.0.1:6379> rpush list r1st r2nd r3rd
(integer) 6

127.0.0.1:6379> lrange list 0 -1
1) "3rd"
2) "2nd"
3) "1st"
4) "r1st"
5) "r2nd"
6) "r3rd"

127.0.0.1:6379> lrange list 0 99
1) "3rd"
2) "2nd"
3) "1st"
4) "r1st"
5) "r2nd"
6) "r3rd"

127.0.0.1:6379> lrange list 99 0
(empty list or set)

127.0.0.1:6379> get list
(error) WRONGTYPE Operation against a key holding the wrong kind of value
```

- `LINDEX [key] [index]`
  - 주어진 인덱스의 원소를 반환

- `LLEN [key]`
  - 리스트의 크기 반환

```redis
127.0.0.1:6379> llen list
(integer) 6
127.0.0.1:6379> lindex list 3
"r1st"
```

- `LPOP / RPOP [key]`
  - 리스트의 첫 번째 / 마지막 원소를 삭제하고 반환

```redis
127.0.0.1:6379> lpop list
"3rd"
127.0.0.1:6379> lindex list 0
"2nd"
127.0.0.1:6379> rpop list
"r3rd"
127.0.0.1:6379> llen list
(integer) 4
```

- `BLPOP / BRPOP [key1] ([key2], ...) [timeout]`
  - 기본 `LPOP / RPOP` 명령의 블로킹 버전
  - 리스트의 원소를 POP할 때 리스트가 비어있으면 제거될 원소가 들어올 때까지 기다림
  - `timeout`으로 설정한 시간초 만큼 블록상태 진입

```redis
# redis1
redis1 127.0.0.1:6379> llen list
(integer) 0
redis1 127.0.0.1:6379> blpop list 100
# 리스트가 현재 비어있으므로 블록상태 진입

...

# redis2 (다른 redis 클라이언트)
redis2 127.0.0.1:6379> lpush list block
(integer) 1
# 레디스 서버의 list에 원소를 추가하면

...
# redis1
# 블록 되어있던 blpop 명령이 진행됨
1) "list"
2) "block"
(24.85s)
```

- `RPOPLPUSH [source] [destination]`
  - `source` 리스트에서 `RPOP`으로 나온 값을 `destination` 리스트에 `LPUSH`
  - `atomic` 명령

- `BRPOPLPUSH [source] [destination] [timeout]`
  - `RPOPLPUSH` 명령의 블로킹 버전

***

## 해시

- 필드를 값으로 매핑할 수 있음
- 객체를 저장하는 데 훌륭한 데이터 구조
- 메모리를 효율적으로 쓸 수 있고 데이터를 빨리 찾을 수 있게 최적화 됨
- 필드 이름과 값은 문자열
- 내부적으로 `ziplist` or `hash table`이 될 수 있음
  - `ziplist`
    - 메모리 효율화에 목적을 둔 양방향 링크드 리스트
    - 정수를 일련의 문자로 저장하지 않고 실제 정수의 값으로 저장
    - 메모리 최적화가 되어 있다 할지라도 일정한 시간 내로 검색이 수행되지는 않음
  - `hash table`
    - 일정한 시간 내로 검색은 되지만 메모리 최적화가 이루어지지 않음

## 해시 명령

- `HSET`
  - 주어진 키의 필드에 값을 저장

| 명령    | `HSET [key] [field] [value]`   |
| :---- | :----------------------------- |
| 지원버전  | >= 2.0.0                       |
| 시간복잡도 | O(1)                           |
| 응답    | <숫자 응답>                        |
| 0     | `field`값이 이미 존재해서 `value`가 갱신됨 |
| 1     | `field`와 `value`값 pair가 추가 됨   |

- `HMSET`
  - `HSET`의 다중 필드 값 버전
  - 필드가 존재하지 않으면 필드를 생성
  - 필드가 이미 존재한다면 필드의 값을 덮어씀

| 명령    | `HMSET [key] [field1] [value1] ([field2] [value2], ...)` |
| :---- | :------------------------------------------------------- |
| 지원버전  | >= 2.0.0                                                 |
| 시간복잡도 | O(N)                                                     |
| 응답    | <상태응답>, OK                                               |

- `HINCRBY / HINCRBYFLOAT [key] [field] [increment]`
  - 주어진 정수 / 부동소수점 만큼 필드를 증가시킴

```redis
# set field value
127.0.0.1:6379> hset movie title 'the war'
(integer) 1
127.0.0.1:6379> hmset movie year 2010 rating 9.2 watchers 100000
OK
127.0.0.1:6379> hincrby movie watchers 10
(integer) 100010

# get field value
127.0.0.1:6379> hget movie title
"the war"
127.0.0.1:6379> hmget movie year rating watchers
1) "2010"
2) "9.2"
3) "100010"
127.0.0.1:6379> hgetall movie
1) "title"
2) "the war"
3) "year"
4) "2010"
5) "rating"
6) "9.2"
7) "watchers"
8) "100010"

# delete field
127.0.0.1:6379> hdel movie watchers
(integer) 1
127.0.0.1:6379> hget movie wathcers
(nil)
```

- `HKEYS [key]`
  - 해당 키에 존재하는 `field` 리스트 조회

- `HVALS [key]`
  - 해당 키에 존재하는 `field`의 `value`값 조회

```redis
127.0.0.1:6379> hkeys movie
1) "title"
2) "year"
3) "rating"
127.0.0.1:6379> hvals movie
1) "the war"
2) "2010"
3) "9.2"
```

- `HSCAN`
  - 해시에 많은 `field`가 존재하고 메모리를 많이 사용할 경우 `HGETALL`의 대안
  - `HGETALL`은 모든 해시 데이터를 네트워크를 통해 전달해야 하므로 레디스 속도를 느리게 함
  - `HSCAN`은 해당 `key`에 `field`가 많을 경우 한 번에 모든 `field`를 리턴하지 않음
  - 커서와 일부 `field`의 값을 리턴함
  - 반복적으로 호출하여 `0`의 커서값을 반환 받으면 모든 해시 `field`데이터를 얻은 것
  - `MATCH pattern` 옵션을 통해 원하는 `field`값만 조회할 수 있음
  - `COUNT count` 옵션을 통해 확인하려는 `field`값의 개수를 제시할 수 있으나  
    레디스 서버에서 자체적으로 처리 시간을 고려하여 개수를 알아서 정함

| 명령    | `HSCAN [key] cursor ([MATCH pattern] [COUNT count])` |
| :---- | :------------------------------------------------------- |
| 지원버전  | >= 2.8.0                                                 |
| 시간복잡도 | O(1)                                                     |
| 응답    | <멀티 벌크 응답>                                               |
| 1) cursor | 모든 `field`를 조회하기 위해서 다음 `HSCAN`에 조회해야할 커서 위치 |
| 2) field | 해당 `HSCAN`명령을 통해 조회가능한 `field` 들 |

```redis
127.0.0.1:6379> hscan movie 1
1) "0"
2) 1) "title"
   1) "the war"
   2) "year"
   3) "2010"
   4) "rating"
   5) "9.2"

127.0.0.1:6379> hscan movie 0 MATCH t*
1) "0"
2) 1) "title"
   2) "the war"
```

***

## 셋 (Set)

- 순서가 보장되지 않으며 중복을 허용하지 않는 컬렉션 (집합)
- 원소의 추가, 삭제 및 검색 성능 속도는 O(1)
- `hash table`로 구현 됨
- 셋은 최대 `2^32 - 1`개의 원소를 가질 수 있음

## 셋 명령
