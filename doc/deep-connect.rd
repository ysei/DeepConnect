= 分散オブジェクトフレームワーク DeepConnect 入門

== DeepConnect とは?

* 分散オブジェクト環境を実現するためのフレームワーク
* fairyで採用

== DeepConnect って何をしてくれるの?

ネットワーク越し, または、別のプロセス空間上のオブジェクトに対し,
メッセージを送り, 実行し, その結果を得ることができる機能を提供する.

シンタックスを重視し, Rubyのメッセージ形式をそのまま利用出きる.

* remote_obj.message(arg1,...)
* remote_obj.message(arg2, ...){...}

もっと分かりやすく言えば、drb と考え方は似ている.

== 歴史

* 1996.11.18 [ruby-list: 1361] で初投稿
* 1997.01.31 [ruby-list: 2009] が最後の投稿
  * たぶん、モチベーションが下がった...
* 1999.07.14 drb 登場
  * そのころソースをいじった形跡があるので、少しやる気が出たらしい (^^;;
* 2001.06 ごろ 別のコンセプトでまた考えている
* 2008.06.22 fairy で適用開始
  * DeepConnect と命名
  * ほとんど修正なしで動作. たぶん, 1999年の時点で動作していたのだろう。
* 2010.10.22 githubに公開
* 2010.10.28 rubygems.org に公開

== DeepConnect入門 - イメージ
== DeepConnect入門 - (1)
サーバー側(受けて側)は以下のように書く:

  dc = DeepConnect::start(port)
  # サービス開始
  dc.export("name", obj)
  # obj を name で参照できるように宣言
  dc.export("RemoteArray", Array)
  # クラスでもexportできる

クライアント側(リクエスト出す側)は以下のようになる:

  dc = DeepConnect::start
  ds = dc.open_deepspace(相手addr, 相手port)
  # 相手(のDeepSpace)と接続
  remote_obj = deepspace.import("name")
  # リモートオブジェクト(の参照)を取得。取っ掛かりのオブジェクトはimportする必要がある。 
  RemoteArray = deepspace.import("RemoteArray")
  # クラスも同様に取得可能

あとは、だいたい普通にRubyのプログラムを組めばよい:

  ret = remote_obj.req
  # 戻り値もリモートオブジェクト（の参照）
  remote_ary = RemoteArray.new
  # サーバー側に配列が作られる。その参照を取得。
  remote_ary.push “foo”
  # さらにリモートオブジェクトにメッセージを送れる

== 特徴

DeepConnectの特徴は以下にあげられる:

* メソッドは参照渡し
* メソッドスペック
* Future型
* 分散GC
* 自動接続
* ShallowConnectモード 

== 特徴 - メソッドは参照渡し

メソッドは参照渡しという意味は, メソッドの引数も戻り値も参照渡しになる
と言うことを意味する. これは, オブジェクト指向システムでは当たり前のこ
とである. オブジェクト指向では, オブジェクトのアイデンティティが重要で
あり, 何の考えもなくオブジェクトのコピーを渡すことはすることは持っての
ほかと言える.

リモートオブジェクトとローカルのオブジェクトを区別なく利用可能になるた
め, オブジェクトの参照渡しを基本とすることによって, 既存プログラムの分
散 化が簡単に実現可能になる. 値(コピー)渡しではそのようなことは不可能
である.

どのオブジェクトをどこに置くかを考えるだけでよくなる. つまり, モデリン
グにおける論理モデル配置モデルとの分離が可能にある

例:  fairyのmapの実装
    def basic_each(&block)
      @map_proc =BBlock.new(@block_source, @context, self)
      @input.each do |e|
        block.call @map_proc.yield(e)
      end
    end

上記の例の場合, @inputが前段のフィルタになっている。これが、リモートの
オブジェクトの場合もあるし、ローカルのオブジェクトの可能性もある。

このように、リモート/ローカルのオブジェクトを区別なく使えることにより、
オブジェクトの分散配置が自由に行えるようになる。これには、クラスを
exportできるのが有効

== 特徴 - メソッドは参照渡しとはいっても

ただし、以下のものは値(コピー)私になっている

* Immutable なもの
* String 

Stringに関しては, パフォーマンスを考えこういう選択になった.
文字列の場合、オブジェクトとして扱うよりは値がほしいことが多いので、実
用上は問題がないことが多い.

さらに、オブジェクトとしてよりも、その値がほしい場合, パフォーマンスを
考えると、その他のオブジェクトでも、そういったことがないわけではない.

また,  組み込みのメソッドの中には参照では困ることが多い.

例えば, Array#& の

  remote_ary & ary

このばあい、Array#& の実装はaryをローカルなオブジェクトとして理解し,
リモートオブジェクトとして扱ってくれない.

== 特徴 - メソッドスペック

メソッドに対し、MethodSpecを指定することにより上記の問題を回避している.
メソッド単位で参照以外を渡すことも可能になる。指定できるのは3種:

* REF  - 参照
* VAL  - シャローコピー
* DVAL - ディープコピー

メソッド引数、戻り値、ブロック引数、ブロック戻り値に指定可能になっている.

  def_method_spec(Object, "VAL to_a()")
  def_method_spec(Array, :method=> :==, :args=> "VAL")

組み込みメソッドに関しては、一通り定義済みになっていて, 前述の Array#& 
の問題は解消している.

クラス単位での指定も出来るが、MethodSpecを使うほうが便利


== 特徴 - Future型

非同期通信を実現するための手段として採用した. 

メッセージを送った後、そのメッセージの結果を待たずに、実行を継続し、実
際に必要になったときに、値があればそれを使い、なければ値が帰るまでまつ。

    v = DeepConnect::future{remote.req}
    # 処理を継続、vがFutureオブジェクト
    v.value			# 実際の値の取得
    v.messege		# Delegatorにもなっている

== 特徴 - 分散GC

他から参照されているオブジェクトは、GCされないようにしている。

参照されなくなったら、GCの対象となるようになっている

リファレンスカウント方式の分散GCを備えている。

  * 完全なGCではないのでごみが残ることもある。
  * かわりに、明示的なリリースメソッドを用意している

== 特徴 - 自動的な接続

必要があれば、自動的に接続する.

最初の取っ掛かりは、明示的接続が必要となる.

    ds = dc.open_deepspace(相手addr, 相手port)
    remote_obj = deepspace.import("name")

接続のされていない空間のオブジェクトの参照が渡されると自動的にその空間
と接続するようになっている。

    remote_obj2 = remote_obj.other_deepspace_opj

複数プロセス間で参照のやり取りがある場合非常に便利になる.


== 特徴 - ShallowConnect モード

DeepConnectは、接続先に対してどんなメソッドも呼び出せてしまう。その特
性から, DeepConnectの名前の由来になっている. ただし, これはこれで、便
利だが、信頼できない相手とのやり取りは危険となる.

そこで, CORBA IDL的な指定ができるモードを用意した. ShallowConnectモー
ドでは, インターフェース宣言されたメソッドだけを利用可能に出来ようにな
る. ただし、すべて宣言しなくてはならないので、かなり面倒

== アーキテクチャ

== 実績

fairyで採用されている. fairy自身はかなり激しい分散並列処理システムでヘ
ビーユーザーさまです. おかげさまで DeepConnect の品質が向上しました(^^;;

fairyローカル版から、fairy分散版への修正は、5% ぐらいの修正で動作した.
その修正も, ほんとんどがオブジェクトのexport/importの指定ぐらい. 


== 注意事項

あまりにも分散を無意識にできてしまうので、注意も必要である.  

構文上同じでも、ネットワーク通信はやっぱりコストがかかる。したがって, 
パフォーマンスのことを考えると, あまりプロセス間通信が発生しないように
細かいメッセージは集約をしたり, 順番を入れ替える必要がある.

不用意な戻り値の問題. Rubyでは, 全てのメソッドに戻り値がある. また, ブ
ロックの実行にも戻り値がある. Rubyで普段プログラミングする上では, 戻り
値を利用しない場合, それをそのまま捨てる(代入しない)ければ, それで済む
が, DeepConnectの場合, 常に戻り値がネットワークを越えて渡ることになる.
これが, パフォーマンスを悪くする要因になりうる. 

Array も参照が渡される. Rubyを理解していれば、だいじょうぶなはずだが、
時々忘れることもある. 

参照に対する == は、equal? になっている。Hash等でパフォーマンス上問題
になるため。このようになっている.



