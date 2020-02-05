# MyProjects
つくった細かいモノ（レポジトリにする必要のなさそうなもの）をあげてみる．

## kyuko_parse - 休講情報をgoogleカレンダーに追加する
仙台高専の授業変更掲示板(http://hirose.sendai-nct.ac.jp/kyuko/kyuko.cgi)  
から休講，変更情報をパースしてきて，googleカレンダーに追加するrubyです．  
結構便利．RaspberryPiを用いて定期的にcronで回して更新させています.  
カレンダーは以下に公開してあります．  
(Calendar ID: 56mcl27h89vhjq7bnlb3af3q7c@group.calendar.google.com)  
(ical: https://calendar.google.com/calendar/ical/56mcl27h89vhjq7bnlb3af3q7c%40group.calendar.google.com/public/basic.ics)

## dmm_make_sakes_reporter
DMM.makeのクリエイターズマーケットの売り上げに変化があった場合にslackに通知するくん.  
cronとかで24時前とかに1日1回まわして使うことを想定しています.  
DMMのlogin_id，password，slack通知するincoming-webhookのURLを環境変数に入れて使います．

## ip_changes_notifier
定期的に実行することで自分のGIPに変更があった場合にslack通知するくんです．  
dotenvを採用しているので.envにslack incoming webhookのendpointを入れて使います．

