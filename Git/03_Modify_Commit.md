# Git 수정 및 저장소에 저장
- 파일을 수정하고 파일의 스냅샷을 커밋하는 과정
- 워킬 디렉토리의 모든 파일은 Tracked(관리대상), Untracked(관리대상 아님)으로 나뉨
- Tracked 파일 
  - 이미 스냅샷에 포함돼있는 파일
  - Unmodified, Modified, Staged 상태중 하나
  - 깃이 알고있는 파일
- Untracked 파일
  - 워킹 디렉토리에 있는 파일 중 스냅샷에도 스테이징 에리어에도 포함되지 않은 파일
  - 깃은 해당 파일이 Tracked되기 전까지 절대 커밋하지 않음
  - ex) 새롭게 추가되거나 삭제된 파일의 경우

<img src="./img/lifecycle.png" width="700">

## 파일의 상태 확인
- `git status` 명령 사용
```
# 아무것도 수정되지 않은 상태
$ git status
On branch master
Your branch is up-to-date with 'origin/master'.
nothing to commit, working directory clean
```
- 위 결과는 Tracked 파일 중에서 수정된 파일이 없을 때 나타남
- Untracked 파일은 없어서 목록에 나타나지 않음
- 현재 작업 중인 브랜치와 서버의 같은 브랜치로부터 진행된 작업이 없음을 보여줌
```
# 새로운 파일을 만드는 경우
$ echo 'My Project' > README
$ git status
On branch master
Your branch is up-to-date with 'origin/master'.
Untracked files:
  (use "git add <file>..." to include in what will be committed)

    README

nothing added to commit but untracked files present (use "git add" to track)
```
- Untracked files 상태는 Untracked 상태를 의미
- README 파일은 Untracked 상태

- `git status -s`명령을 사용하면 더 짧게 확인 가능
```
$ git status -s
 M README
MM Rakefile
A  lib/git.rb
M  lib/simplegit.rb
?? LICENSE.txt
```
- `??` : Untracked 파일
- `A` : Staged 상태로 추가한 파일 중 새로 생성한 파일
- `M` : Staged 상태로 추가한 파일 중 수정 한 파일
- 상태 정보는 두 컬럼으로 나타남
  - 왼쪽 : 스테이징 에리어에서의 상태
  - 오른쪽 : 워킹 트리에서의 상태
- 위 결과 설명
  - `README` : 내용은 변경했지만 Staged 상태가 아님을 의미
  - `lib/simplegit.rb` : 내용을 변경하고 Staged 상태로 추가한 단계
  - `Rakefile` : 내용을 변경해서 Staged 상태로 추가하고 난 후 또 한번 내용을 변경하고 Unstaged 상태인 단계

## 파일을 새로 추적
- `git add` 명령으로 파일을 Tracked 상태로 변환 가능
```
$ git add README

$ git status
On branch master
Your branch is up-to-date with 'origin/master'.
Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

    new file:   README
```
- Changes to be committed 상태는 Staged 상태를 의미
- README 파일은 현재 Staged 상태로 변함
- 디렉토리일 경우 하위 파일들까지 재귀적으로 추가

## Modified 상태의 파일을 Stage 하기
- 이미 Tracked 상태인 파일을 수정할 시 Modified 상태가 됨
```
$ git status
On branch master
Your branch is up-to-date with 'origin/master'.
Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

    new file:   README

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

    modified:   CONTRIBUTING.md
```
- Changes not staged for commit 상태는 Modified 상태를 의미
- Tracked 상태이지만 아직 Staged 상태가 아님
- 마찬가지로 `git add`명령을 통해 Staged 상태로 변환 가능
```
$ git add CONTRIBUTING.md
$ git status
On branch master
Your branch is up-to-date with 'origin/master'.
Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

    new file:   README
    modified:   CONTRIBUTING.md
```

※ `git add`명령은 파일을 다음 커밋에 추가한다고 생각

- 만약 Staged 파일을 수정할 경우 해당 파일은 다시 Modified 상태가 되지만  
  `git add`명령을 실행한 당시의 수정사항 까지는 Staged 상태가 됨

## 파일 무시
- 깃이 관리할 필요가 없는 파일이 존재할 경우 (로그 파일, 빌드 시스템 종속 파일)
- `.gitignore` 파일로 처리 가능
```
$ cat .gitignore
*.[oa]            # 확장자가 '.o', '.a'인 파일 무시
*~                # '~'로 끝나는 모든 파일 무시
```
- `.gitignore`파일에 무시할 파일의 패턴을 추가
- `.gitignore` 파일의 규칙
  - 아무것도 없는 라인이나 `#`로 시작하는 라인은 무시
  - 표준 Glob 패턴 사용 (프로젝트 전체에 적용됨)
  - 슬래시(`/`)로 시작하면 하위 디렉토리에 적용되지 않음
  - 디렉토리는 슬래시(`/`)를 끝에 사용하는 것으로 표현
  - 느낌표(`!`)로 시작하는 패턴의 파일은 무시하지 않음

※ Glob 패턴은 정규식을 단순하게 만든 것
  - `*` : 문자가 0개 이상
  - `[abc]` : 중괄호 안에 있는 문자 중 하나를 의미 (`a`,`b`,`c` 중 하나)
  - `?` : 문자 하나
  - `[0-9]` : 중괄호 안의 캐릭터 사이에 `-`을 사용하면 해당 캐릭터들 사이의 문자 하나
  - `a/**/z` : `*`를 2개 사용하여 재귀적인 디렉토리까지 지정가능 (`a/z`, `a/b/z`, `a/b/c/z` ...)
```
# 확장자가 .a인 파일 무시
*.a

# 윗 라인에서 확장자가 .a인 파일은 무시하게 했지만 lib.a는 무시하지 않음
!lib.a

# 현재 디렉토리에 있는 TODO파일은 무시하고 subdir/TODO처럼 하위디렉토리에 있는 파일은 무시하지 않음
/TODO

# build/ 디렉토리에 있는 모든 파일은 무시
build/

# doc/notes.txt 파일은 무시하고 doc/server/arch.txt 파일은 무시하지 않음
doc/*.txt

# doc 디렉토리 아래의 모든 .pdf 파일을 무시
doc/**/*.pdf
```

## Staged, Unstaged 상태 변경 내용 확인
- `git diff` 명령을 통해 파일의 변경 내용 확인 가능
```
# READ 파일을 수정해서 Staged 상태로 만들고, CONTRIBUTING.md 파일은 수정만 해둔 상태
$ git status
On branch master
Your branch is up-to-date with 'origin/master'.
Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

    modified:   README

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

    modified:   CONTRIBUTING.md

# git diff 명령을 수행하면 Staged 상태 파일과 비교 가능
$ git diff
diff --git a/CONTRIBUTING.md b/CONTRIBUTING.md
index 8ebb991..643e24f 100644
--- a/CONTRIBUTING.md
+++ b/CONTRIBUTING.md
@@ -65,7 +65,8 @@ branch directly, things can get messy.
  Please include a nice description of your changes when you submit your PR;
  if we have to read the whole diff to figure out why you're contributing
  in the first place, you're less likely to get feedback and have your change
-merged in.
+merged in. Also, split your changes into comprehensive chunks if your patch is
+longer than a dozen lines.

  If you are starting to work on a particular area, feel free to submit a PR
  that highlights your work in progress (and note in the PR title that it's
```
- `a/CONTRIBUTING.md` : Staged 상태의 파일 (Staged 된 해당 파일이 없으면 가장 최근 커밋된 버전)
- `b/CONTRIBUTING.md` : 워킹 디렉토리의 파일
- `git diff`는 Unstaged 상태인 것들과 Staged 상태(Staged 상태가 없는 경우 가장 최근 커밋된 버전)와의 차이만 보여줌
- 때문에 수정한 파일을 모두 스테이징 에리어에 넣었다면 아무것도 출력하지 않음

- `git diff --staged` : 스테이징 에리어의 파일과 커밋 하려는 파일의 변경 부분을 보고 싶은 경우
- `git diff --cached`와 같은 명령
```
$ git diff --staged
diff --git a/README b/README
new file mode 100644
index 0000000..03902a1
--- /dev/null
+++ b/README
@@ -0,0 +1 @@
+My Project
```
- `a/README` : 커밋 기준 최신 상태의 파일
- `b/README` : Staged 상태의 파일
- `git diff --staged`는 Staged 상태의 파일과 가장 최근 커밋된 파일과의 차이를 보여줌
- `git diff`와 비슷하게 Staged 파일이 하나도 없는 경우 아무것도 출력하지 않음

## 변경사항 커밋
- 스테이징 에리어에 수정한 파일들은 `git commit` 명령을 통해 커밋 가능
- `git commit` 명령을 실행할 경우 깃 설치시 지정했던 편집기가 실행됨
- `git config --global core.editor` 명령으로 편집기 설정 변경 가능
```
# vim의 예시
# Please enter the commit message for your changes. Lines starting
# with '#' will be ignored, and an empty message aborts the commit.
# On branch master
# Your branch is up-to-date with 'origin/master'.
#
# Changes to be committed:
#	new file:   README
#	modified:   CONTRIBUTING.md
#
~
~
~
".git/COMMIT_EDITMSG" 9L, 283C
```
- 커밋한 내용을 쉽게 기억할 수 있도록 이 메세지를 포함할 수 있고 새로 작성할 수도 있음
- `git commit` 명령에 `-v` 옵션을 추가하면 `diff` 내용도 추가됨
- 내용을 저장하고 편집기를 종료하면 깃은 입력된 내용을 메시지로 하는 커밋을 완성
- `git commit -m "<msg>"` 명령으로 인라인으로 메시지를 추가할 수도 있음
```
$ git commit -m "Story 182: Fix benchmarks for speed"
[master 463dc4f] Story 182: Fix benchmarks for speed
  2 files changed, 2 insertions(+)
  create mode 100644 README
```
- 위 예제는 `master`브랜치에 커밋했고 체크섬은 `463dc4f`임을 알려줌
- 또한 수정한 파일의 개수, 삭제 혹은 추가된 라인의 개수를 알려줌

## 스테이징 에리어 생략
- 커밋할 파일을 정리하는 스테이징 에리어를 스킵해서 바로 커밋시킬 수 있음
- `git commit -a` 옵션으로 커밋하면 Tracked 상태의 파일을 자동으로 스테이징 에리어에 넣음
```
$ git status
On branch master
Your branch is up-to-date with 'origin/master'.
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

    modified:   CONTRIBUTING.md

no changes added to commit (use "git add" and/or "git commit -a")
$ git commit -a -m 'added new benchmarks'
[master 83e38c7] added new benchmarks
 1 file changed, 5 insertions(+), 0 deletions(-)
```
- 위 예시에서는 `git add`명령으로 CONTRIBUTING.md를 추가하지 않았음에도 바로 commit됨
- 단, `git commit -a` 옵션을 사용하면 Tracked 상태의 모든 파일을 `git add`한다고 봐야함
- 즉, `git commit -a`는 `git add --all`, `git commit` 두 단계를 축약한 것

