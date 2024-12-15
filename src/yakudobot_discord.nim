import os, dimscord, asyncdispatch, options, sequtils, strutils, strformat, times
import ./pkg/[yakudo_core, database]

let botToken = os.getEnv("DISCORD_BOT_TOKEN")
let discord = newDiscordClient(botToken)

proc guildCreate(s: Shard, guild: Guild) {.event(discord).} =
  echo "GuildCreate: ", guild.name
  # サーバーが追加されたらDBに追加
  await insertNewServer(guild.id)

proc InteractionCreate(s: Shard, i: Interaction) {.event(discord).} =
  let data = i.data.get
  if i.data.name == "register":
    let serverId = i.guild_id
    let channelId = i.channel_id
    await insertNewChannel(channelId, serverId, true)
    await i.reply("登録完了！")
  # TODO: unregisterコマンドの実装
  if i.data.name == "unregister":
    let serverId = i.guild_id
    let channelId = i.channel_id
    await updateChannel(channelId, false)
    await i.reply("登録解除完了！")

proc postAwardMessage*(s: Shard, server_id: string, score: Scores) {.async.} =
  # 表彰メッセージを投稿する
  let awardChannelIds = await getAwardChannels(server_id)
  if awardChannelIds.len > 0:
    for channelId in awardChannelIds:
      # 表彰メッセージを作成
      var message = "本日の最高得点はこちらです！\n"
      message &= fmt"ユーザー: <@{score.user_id}>\n"
      message &= fmt"スコア: {score.score}\n"
      message &= fmt"メッセージ: https://discord.com/channels/{server_id}/{score.servers_id.server_id}/{score.message_id}"

      discard await s.api.sendMessage(
        channelId,
        message
      )

proc dailyAwardProcess(s: Shard) {.async.} =
  # 現在の日付を取得（YYYY-MM-DD形式）
  let today = now().jstTimeStr

  # データベースから全てのサーバーを取得
  let allServers = dbConn.selectAll(Servers)

  # 各サーバーに対して処理を実行
  for server in allServers:
    # その日の最高スコアを取得
    let highScore = await getDailyHighScore(server.server_id, today)

    # 最高スコアがあり、かつまだ表彰されていない場合、表彰メッセージを投稿
    if highScore.isSome:
      if not (await isScoreAwarded(highScore.get.id, today)):
        await postAwardMessage(s, server.server_id, highScore.get)
        # 表彰済みスコアをデータベースに記録
        await insertAwardedScore(highScore.get, today)
        # 表彰が完了した前日以前のスコアを削除
        await deleteScores(today)

proc messageCreate(s: Shard, msg: Message) {.event(discord).} =
  # botからのメッセージは無視
  if msg.author.bot: return
  
  # botへのメンションがない場合は無視
  if not msg.mention_users.anyIt(it.id == s.user.id): return
  
  # 添付ファイルがある場合の処理
  if msg.attachments.len > 0:
    var scores: seq[tuple[index: int, score: float64]] = @[]
    var isGoodYakudo: bool = true
    var isScoreInf: bool = false

    for i, attachment in msg.attachments:
      if attachment.contentType.isSome and attachment.contentType.get().startsWith("image/"):
        # 画像ファイルへの返信
        let image = getImageFromUrl(attachment.url)
        if image.isNil:
          discard await discord.api.sendMessage(
            msg.channel_id,
            "エラー！画像の取得に失敗しました。",
            message_reference = some MessageReference(
              message_id: some msg.id,
              channel_id: some msg.channel_id,
              guild_id: msg.guild_id
            )
          )
          return
        else:
          let score: float64 = calcYakudoScore(image)
          scores.add((i + 1, score))
          if score <= 100:
            isGoodYakudo = false
          elif score == Inf:
            isScoreInf = true
            
      elif attachment.contentType.isSome and attachment.contentType.get().startsWith("video/"):
        # 動画ファイルへの返信
        discard await discord.api.sendMessage(
          msg.channel_id,
          "やめろ！クソ動画を投稿するんじゃない!",
          message_reference = some MessageReference(
            message_id: some msg.id,
            channel_id: some msg.channel_id,
            guild_id: msg.guild_id
          )
        )
        return
      elif attachment.contentType.isSome and attachment.contentType.get().startsWith("audio/"):
        # 音声ファイルへの返信
        discard await discord.api.sendMessage(
          msg.channel_id,
          "やめろ！クソ音声を投稿するんじゃない!",
          message_reference = some MessageReference(
            message_id: some msg.id,
            channel_id: some msg.channel_id,
            guild_id: msg.guild_id
          )
        )
        return
    var replyMessage = if isGoodYakudo: "GoodYakudo！\n" else: "もっとyakudoしろ！\n"
    let highScore = max(scores.mapIt(it.score))

    for item in scores:
      replyMessage &= fmt"{item.index}枚目: {item.score}{'\n'}"

    if isScoreInf:
      replyMessage &= "ちょっと待って！不正が入ってるやん！\n"
    
    discard await discord.api.sendMessage(
      msg.channel_id,
      replyMessage,
      message_reference = some MessageReference(
        message_id: some msg.id,
        channel_id: some msg.channel_id,
        guild_id: msg.guild_id
      )
    )
    # MessageのSnowflakeIDからタイムスタンプ YYYY-MM-DDを取得
    let date = msg.id.timestamp.jstTimeStr
    # DBにスコアを追加
    await insertNewScore(get(msg.guild_id), msg.author.id, msg.id, highScore, date)
  else:
    # 添付ファイルがない場合
    discard await discord.api.sendMessage(
      msg.channel_id,
      "画像が入ってないやん!\n",
      message_reference = some MessageReference(
        message_id: some msg.id,
        channel_id: some msg.channel_id,
        guild_id: msg.guild_id
      )
    )

proc onReady(s: Shard, r: Ready) {.event(discord).} =
  echo "Ready!"
  let commands = @[
    ApplicationCommand(
      name: "register",
      description: "register this channel to the bot"
    ),
    ApplicationCommand(
      name: "unregister",
      description: "unregister this channel from the bot"
    )
  ]
  discard await discord.api.bulkOverwriteApplicationCommands(s.user.id, commands)

waitFor initDatabase()
waitFor discord.startSession()
