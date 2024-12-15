import norm/[model, pragmas]

type
  Servers* = ref object of Model
    server_id* {.unique.}: string

  Scores* = ref object of Model
    servers_id*: Servers
    user_id*: string
    message_id*: string
    score*: float64
    date*: string

  Channels* = ref object of Model
    channel_id*: string
    server_id*: Servers
    is_award_channel*: bool

func newServers*(server_id = ""): Servers =
  result = Servers(server_id: server_id)

func newScores*(servers_id = newServers(), user_id = "", message_id = "", score = 0.0, date = ""): Scores =
  result = Scores(servers_id: servers_id, user_id: user_id, message_id: message_id, score: score, date: date)

func newChannels*(channel_id = "", server_id = newServers(), is_award_channel = false): Channels =
  result = Channels(channel_id: channel_id, server_id: server_id, is_award_channel: is_award_channel)