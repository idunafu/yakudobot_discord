import os, dimscord, asyncdispatch, options, sequtils, strutils, strformat
import ./pkg/yakudo_core

let botToken = os.getEnv("DISCORD_BOT_TOKEN")
let discord = newDiscordClient(botToken)

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

waitFor discord.startSession()
