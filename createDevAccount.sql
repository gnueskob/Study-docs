# 개발자 전용 계정 만들기
# mysql root 계정으로 접속하여 진행

# 계정 생성
# GRANT USAGE ON *.* TO '계정명'@'%' IDENTIFIED BY '비밀번호';
GRANT USAGE ON *.* TO 'gnues'@'%' IDENTIFIED BY '1234';
FLUSH PRIVILEGES;

# 계정이 제대로 생성 되었는지 확인
USE mysql;
SELECT * FROM user;

# 개발자 전용 계정으로 사용할 DB 생성
CREATE DATABASE `BASICTRAINING`;
SHOW DATABASES;

# 해당 DB에 대해서 개발자 계정에 모든 권한 부여
GRANT ALL PRIVILEGES ON BASICTRAINING.* TO 'gnues'@'%';
FLUSH PRIVILEGES;