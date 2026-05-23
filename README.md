# yakudobot for discord

yakudo 写真をつけてメンションすると、評価してくれる Discord bot です。

## 概要

- オリジナルの [mkihr-ojisan/yakudobot](https://github.com/mkihr-ojisan/yakudobot) を起点に、Misskey 向け Rust 版 [mkihr-ojisan/yakudobot_rs](https://github.com/mkihr-ojisan/yakudobot_rs) や Nim 版を経て、本リポジトリでは **Rust + serenity + OpenCV** で実装しています。
- yakudo score は OpenCV の `Laplacian` と `meanStdDev` を使って算出します。

## 必要環境

- Rust 1.88.0 以上 (`rust-toolchain.toml` で固定)
- OpenCV 4.x
- LLVM / Clang (`opencv` クレートのバインディング生成に必要)

### OpenCV のセットアップ例

#### Windows

- [vcpkg](https://vcpkg.io/) で OpenCV をインストールする例:

```powershell
vcpkg install opencv4:x64-windows
```

- 必要に応じて以下の環境変数を設定します:

```powershell
$env:OPENCV_LINK_LIBS = "opencv_world480"
$env:OPENCV_LINK_PATHS = "C:\path\to\vcpkg\installed\x64-windows\lib"
$env:OPENCV_INCLUDE_PATHS = "C:\path\to\vcpkg\installed\x64-windows\include"
```

#### Linux (Debian/Ubuntu)

推奨環境です。依存関係のインストールとビルド:

```bash
sudo apt install libopencv-dev clang llvm-dev libclang-dev pkg-config
cargo build --release
```

#### macOS

```bash
brew install opencv llvm
```

## 起動方法

1. Discord Developer Portal で Bot Token を取得
2. 環境変数 `DISCORD_BOT_TOKEN` を設定
3. ビルドして起動

```bash
export DISCORD_BOT_TOKEN="your-token-here"
cargo run --release
```

Windows PowerShell の例:

```powershell
$env:DISCORD_BOT_TOKEN = "your-token-here"
cargo run --release
```

## 使い方

1. Bot をサーバーに招待
2. Bot へメンション付きで画像を添付して投稿
3. Bot が yakudo score を返信

### 返信例

- スコアが十分高い場合: `GoodYakudo！`
- スコアが低い場合: `もっとyakudoしろ！`
- 分散 0 の場合: `ちょっと待って！不正が入ってるやん！`

## 未実装機能

- Highest score [issue](https://github.com/idunafu/yakudobot_discord/issues/1)

## ライセンス

MIT
