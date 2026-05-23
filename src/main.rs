mod yakudo;

use anyhow::{Context, Result};
use serenity::{
    all::{CreateMessage, GatewayIntents, Message},
    async_trait,
    client::{Context, EventHandler},
    Client,
};
use std::env;

struct Handler {
    http_client: reqwest::Client,
}

#[async_trait]
impl EventHandler for Handler {
    async fn message(&self, ctx: Context, msg: Message) {
        if msg.author.bot {
            return;
        }

        let bot_id = ctx.cache.current_user().id;

        if !msg.mentions.iter().any(|user| user.id == bot_id) {
            return;
        }

        if let Err(error) = handle_message(&ctx, &msg, &self.http_client).await {
            tracing::error!(?error, "failed to handle message");
        }
    }
}

async fn handle_message(
    ctx: &Context,
    msg: &Message,
    http_client: &reqwest::Client,
) -> Result<()> {
    if msg.attachments.is_empty() {
        reply(ctx, msg, "画像が入ってないやん!\n").await?;
        return Ok(());
    }

    let mut scores = Vec::new();
    let mut is_good_yakudo = true;
    let mut is_score_inf = false;

    for (index, attachment) in msg.attachments.iter().enumerate() {
        let content_type = attachment.content_type.as_deref().unwrap_or("");

        if content_type.starts_with("image/") {
            let image_bytes = match yakudo::fetch_image_bytes(http_client, &attachment.url).await {
                Ok(bytes) => bytes,
                Err(error) => {
                    tracing::error!(?error, url = %attachment.url, "failed to fetch image");
                    reply(ctx, msg, "エラー！画像の取得に失敗しました。").await?;
                    return Ok(());
                }
            };

            let score = yakudo::calc_yakudo_score(&image_bytes)
                .with_context(|| format!("failed to calculate yakudo score for attachment {}", index + 1))?;

            scores.push((index + 1, score));

            if score <= 100.0 {
                is_good_yakudo = false;
            }
            if score.is_infinite() {
                is_score_inf = true;
            }
        } else if content_type.starts_with("video/") {
            reply(ctx, msg, "やめろ！クソ動画を投稿するんじゃない!").await?;
            return Ok(());
        } else if content_type.starts_with("audio/") {
            reply(ctx, msg, "やめろ！クソ音声を投稿するんじゃない!").await?;
            return Ok(());
        }
    }

    if scores.is_empty() {
        reply(ctx, msg, "画像が入ってないやん!\n").await?;
        return Ok(());
    }

    let mut reply_message = if is_good_yakudo {
        String::from("GoodYakudo！\n")
    } else {
        String::from("もっとyakudoしろ！\n")
    };

    for (index, score) in scores {
        reply_message.push_str(&format!("{index}枚目: {score}\n"));
    }

    if is_score_inf {
        reply_message.push_str("ちょっと待って！不正が入ってるやん！\n");
    }

    reply(ctx, msg, reply_message.trim_end()).await?;
    Ok(())
}

async fn reply(ctx: &Context, msg: &Message, content: impl Into<String>) -> Result<()> {
    msg.channel_id
        .send_message(
            &ctx.http,
            CreateMessage::new()
                .content(content)
                .reference_message(msg),
        )
        .await
        .context("failed to send reply message")?;

    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let token = env::var("DISCORD_BOT_TOKEN").context("DISCORD_BOT_TOKEN is not set")?;

    let intents = GatewayIntents::GUILD_MESSAGES
        | GatewayIntents::DIRECT_MESSAGES
        | GatewayIntents::MESSAGE_CONTENT;

    let http_client = reqwest::Client::new();
    let handler = Handler { http_client };

    let mut client = Client::builder(token, intents)
        .event_handler(handler)
        .await
        .context("failed to create Discord client")?;

    if let Err(error) = client.start().await {
        return Err(error.into());
    }

    Ok(())
}
