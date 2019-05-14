# 레디스 내부구조

## 레디스 객체

- 레디스는 저장된 데이터를 관리하기 위해 `redisObject` 객체를 사용
- 문자열, 해시 데이터는 모두 `redisObject` 사용
- `redisObject`가 관리하는 정보
  - 저장된 객체의 데이터 형
  - 인코딩 정보
  - 객체가 참조된 횟수
  - LRU 시간 정보
- `redisObject`객체는 레디스의 거의 모든 코드에서 사용됨
- 레디스에 저장된 모든 데이터와 키의 표현에 사용됨

```c
// redis.h
typedef struct redisObject {
  unsigned type:4;
  unsigned notused:2;
  unsigned encoding:4;
  unsigned lru:22;
  int refcount;
  void *ptr;
} robj;
```

- 상위 4개의 변수에서 사용된 콜론 `:`기호 (비트 필드)
  - C언어의 구조체에서 할당된 데이터형을 콜론 기호 뒤의 숫자에 해당하는 길이만큼만 사용
  - 비트 필드는 주어진 크기의 데이터를 비트 단위로 잘라서 사용할 수 있음
  - 32비트크기의 변수를 각각 4, 2, 4, 22 비트만큼 할당하여 사용

```text
# redisObject 상위 4 variables

                      lru                   encoding notused type
 ┌─────────────────────┴──────────────────┐ ┌───┴───┐ ┌┴┐ ┌───┴─┐
+-+-+-----+-+-+ +-+-+-----+-+-+ +-+-+----+-+-+-+ +-+-+-+-+-+-+-+-+
|0|0| ... |0|0| |0|0| ... |0|0| |0|0| ...|0|0|0| |0|0|0|0|0|0|0|0|
+-+-+-----+-+-+ +-+-+-----+-+-+ +-+-+----+-+-+-+ +-+-+-+-+-+-+-+-+
[32]       [24] [23]       [17] [16]         [8] [7]           [0]
```

- `type` : 레디스에 저장된 객체의 데이터 형을 나타냄 (레디스가 지원하는 5가지 데이터형)
  - `0: REDIS_STRING`
  - `1: REDIS_LIST`
  - `2: REDIS_SET`
  - `3: REDIS_ZSET`
  - `4: REDIS_HASH`
- `notused` : 사용되지 않는 필드
- `encoding` : 레디스 객체에 저장된 데이터의 인코딩 타입
  - 레디스가 데이터를 저장할 때 지정한 이코딩 타입이 저장됨
- `lru` : 저장된 데이터의 LRU 시간정보
  - 데이터가 처음 생성되거나 변경된 시간이 기록됨
- `refcount` : 이 객체가 참조된 횟수 정보
  - 레디스 내부에서 다른 키에 의해서 참조되고 있는 횟수
- `*ptr` : 실제 데이터가 저장된 위치 정보 (포인터)

```redis
127.0.0.1:6379> set key:sample 'Test String'
OK
127.0.0.1:6379> debug object key:sample
Value at:00007FCD438E8160 refcount:1 encoding:embstr serializedlength:12 lru:14332053 lru_seconds_idle:9
```

- `debug object` 명령을 통해 해당 키에 저장된 `redisObject`의 상태 확인 가능

- `encoding` 상수 목록 (v2.6)
  - `REDIS_ENCODING_RAW` : 인코딩 되지 않은 바이트 배열 형태의 데이터
  - `REDIS_ENCODING_INT` : 숫자 형태의 데이터
    - 레디스객체에 저장되는 문자열 데이터가 long 범위일 때 지정됨
  - `REDIS_ENCODING_HT` : 해시 테이블 형태의 데이터 (셋 데이터 형의 내부 구현형태)
  - `REDIS_ENCODING_ZIPMAP` : (deprecated) 압축된 해시 테이블 형태
  - `REDIS_ENCODING_LINKEDLIST` : 일반적인 연결 리스트 형태
  - `REDIS_ENCODING_ZIPLIST` : 압축된 형태의 연결 리스트 인코딩
    - 2.6 이상에서 `REDIS_ENCODING_ZIPMAP` 대신 사용
  - `REDIS_ENCODING_INTSET` : 셋 데이터형에 데이터 저장시 사용하는 특별한 인코딩
    - 데이터가 모두 숫자로 구성되어있을 때 사용
  - `REDIS_ENCODING_SKIPLIST` : 정렬된 셋 데이터형에 사용되는 기본 인코딩

***

## 레디스 인코딩

- 레디스는 메모리에 데이터를 효율적으로 저장하기 위해 인코딩 사용

### 문자열 데이터 인코딩

- `RAW` : 전혀 가공되지 않은 원본 데이터
  - (`REDIS_ENCODING_RAW`, 이하 REDIS_ENCODING 생략)
  - value가 string이고 45문자 이상
- `INT` : 숫자 데이터
  - value가 정수
  - integer, 부동소수점은 string으로 분류됨
  - ex) `123` : int, `0123` : embstr
- `EMBSTR` : (embedded string, v3.0 이상), value가 string이고 44문자 이하

```redis
127.0.0.1:6379> set key 1234
OK
127.0.0.1:6379> object encoding key
int
127.0.0.1:6379> append key Hello
OK
127.0.0.1:6379> object encoding key
embstr
127.0.0.1:6379> set key 01234
OK
127.0.0.1:6379> object encoding key
embstr
127.0.0.1:6379> set key 12.34
OK
127.0.0.1:6379> object encoding key
embstr
127.0.0.1:6379> set key 0123456789012345678901234567890123456789
OK
127.0.0.1:6379> object encoding key
raw
```

- 레디스는 10000보다 작은 숫자를 미리 `공유객체 상수`로 등록하여 같은 객체를 사용
- 동일한 값을 가지는 데이터를 한 번만 저장하므로 메모리 낭비를 막음
  - 100개의 키에 `1234`값 저장시 레디스는 `1234`의 데이터를 별도의 공간에 저장하지 않음

### 리스트 데이터 인코딩

- v3.2.0 이전
  - `ZIP_LIST` : member 갯수 <= 512 or 값의 길이 <= 64
  - `LINKED_LIST` : member 갯수 > 512 or 값의 길이 > 64
- v3.2.0 이후
  - `QUICK_LIST` : `ZIP_LIST`, `LINKED_LIST` 통합

```redis
127.0.0.1:6379> rpush mylist3 value1 value2
(integer) 2
127.0.0.1:6379> object encoding mylist3
quicklist
```

### 셋 데이터 인코딩

- `INTSET` : value가 모두 정수, member 갯수 <= 512
  - 메모리를 절약하기 위한 인코딩
  - value가 0으로 시작하거나, 부동소수점을 포함하면 `HT`로 변환
- `HT` : value가 string이거나 member 갯수 > 512
- member 갯수는 `set-max-intset-entries` 설정에 따름

```redis
127.0.0.1:6379>sadd myset 1 2 3
(integer) 3
127.0.0.1:6379>object encoding mylist1
intset
127.0.0.1:6379>sadd myset 4.1
(integer) 1
127.0.0.1:6379>object encoding myset
hashtable
```

### 정렬된 셋 데이터 인코딩

- `ZIP_LIST` : member 갯수 <= 128, 값의 길이 <= 64
- `SKIP_LIST` : member 갯수 > 128, 값의 길이 > 64
- 해당 설정은 `zset-max-ziplist-entris`, `zset-max-ziplist-value`로 변경 가능

```redis
127.0.0.1:6379>zcard myzip1
(integer) 128
127.0.0.1:6379>object encoding myzip1
ziplist
127.0.0.1:6379>zcard myzip2
(integer) 129
127.0.0.1:6379>object encoding myzip2
skiplist
```

### 해시 데이터 인코딩

- `ZIP_LIST` : member 갯수 <= 512, 값의 길이 <= 64
- `HT` : member 갯수 > 512, 값의 길이 > 64
- 해당 설정은 `hash-max-ziplist-entries`, `hash-max-ziplist-value`로 변경 가능

```redis
127.0.0.1:6379>hlen myhash1
(integer) 512
127.0.0.1:6379>object encoding myhash1
ziplist
127.0.0.1:6379>hlen myhash2
(integer) 513
127.0.0.1:6379>object encoding myhash2
hashtable
```

***

## 레디스 문자열

- 레디스는 문자열을 메모리에 저장할 때 C언어 `char *`를 사용
- 또한 문자열 데이터에 대한 빠른 연산을 위해 특별한 구조체 사용

```c
// sds.h
struct sdshdr {
  int len;
  int free;
  char buf[];
};
```

- SDS(Simple Dynamic Strings) : 레디스 문자열 처리 라이브러리 집합
- `len` : 저장된 문자열의 길이
- `free` : 할당된 버퍼의 남은 길이 저장, 문자열 값 추가시 새로운 메모리 할당 여부 결정에 사용
- `buf[]` : 문자열 데이터 저장

```c
typedef char *sds;
```

- 레디스는 `sds`, `sdshdr`을 통해 문자열을 처리
- 단순히 `sds(char *)`를 가지고 `sdshdr`을 구조체를 다룸

```c
size_t sdslen(const sds s) {
  struct sdshdr *sh = (void *) (s - sizeof(struct sdshdr));
  return sh->len;
}
```

- `sds` 변수의 메모리 주소를 이용하여 `sdshdr` 구조체의 메모리 주소 접근

***

## 레디스 공유 객체

- 레디스는 자주 사용되는 값을 전역 변수인 공유객체에 저장해 두고 사용
- 에러 메시지, 프로토콜을 위한 문자열, 자주 사용되는 문자열, 0 ~ 9999 숫자에 해당
- 모든 값은 `redisObject`로 표현됨

```c
...
for (j = 0; j < REDIS_SHARED_INTEGERS; j++) {
  shared.integers[j] = createObject(REDIS_STRING, (void *) (long) j);
  shared.integers[j]->encoding = REDIS_ENCODING_INT;
}
...
```

- `REDIS_SHARED_INTEGERS`는 `redis.h`에 10000으로 설정되어 있음
- 해당 값을 크게 잡을 수록 메모리를 더 소모하여 공유객체를 많이 설정 가능