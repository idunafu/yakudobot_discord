import options, asyncdispatch, sequtils
import norm/[model, sqlite]
import models

var dbConn: DbConn

proc initDatabase*() {.async.} =
  dbConn = open("yakudodb.db", "", "", "")
  createTables(dbConn, newScores())
  createTables(dbConn, newChannels())

proc insertNewServer*(server_id: string) {.async.} =
  var server = newServers(server_id)
  dbConn.insert(server)

proc insertNewScore*(server_id: string, user_id: string, message_id: string, score: float64, date: string) {.async.} =
  var server = newServers(server_id)
  var newScore = newScores(server, user_id, message_id, score, date)
  dbConn.insert(newScore)

proc insertNewChannel*(channel_id: string, server_id: string) {.async.} =
  var server = newServers(server_id)
  var newChannel = newChannels(channel_id, server)
  dbConn.insert(newChannel)

proc getAwardChannels*(server_id: string): Future[seq[string]] {.async.} =
  var channels: seq[Channels] = @[]
  dbConn.select(channels, "server_id = ? AND is_award_channel = ?", server_id, true)
  return channels.mapIt(it.channel_id)

proc updateChannel*(channel_id: string, is_award_channel: bool) {.async.} =
  # チャンネルの表彰用チャンネルフラグを更新
  var channel: Channels
  dbConn.select(channel, "channel_id = ?", channel_id)
  if not channel.isNil:
    channel.is_award_channel = is_award_channel
    dbConn.update(channel)

proc deleteScores*(date: string) {.async.} =
  # 指定された日付より古いスコアを削除
  var scores: seq[Scores]
  dbConn.select(scores, "date < ?", date)
  dbConn.delete(scores)

proc getDailyHighScore*(server_id: string, date: string): Future[Option[Scores]] {.async.} =
  # 指定された日付の指定されたサーバーのスコアを降順にソートして取得
  let scores = dbConn.selectAll(Scores, servers_id == Servers(server_id: server_id) and date == date, order = sql"score DESC")
  if scores.len > 0:
    return some(scores[0])
  else:
    return none(Scores)

proc closeDatabase*() =
  if not dbConn.isNil:
    dbConn.close()