# dotfiles

[GNU Stow](https://www.gnu.org/software/stow/) で管理する macOS 用 dotfiles。

## クリーン macOS でのセットアップ

新しい mac で以下を 1 行実行するだけで、Homebrew インストールから dotfiles 適用まで完了します。

```sh
bash <(curl -fsSL https://gist.githubusercontent.com/jayemdot/a5c4129e41cf20af06b6fbe2866d0248/raw/bootstrap.sh)
```

途中で `gh auth login` の対話プロンプトが出るので、ブラウザで GitHub 認証してください。

すでに repo を clone 済みの場合:

```sh
cd ~/dotfiles && ./setup.sh
```

完了後:

```sh
exec zsh                 # 新しい設定を読み込む
tmux                     # tmux を起動
# tmux 内で  prefix + I  を押してプラグインをインストール
```

## リポジトリ構成

| パス | 役割 |
|------|------|
| `bootstrap.sh` | クリーン macOS 用ブートストラップ。Gist にもミラーされる |
| `setup.sh` | clone 済み repo から実行する冪等なセットアップ |
| `.githooks/post-commit` | `bootstrap.sh` の変更を Gist に自動同期 |
| `brew/.Brewfile` | Homebrew パッケージ・cask・Mac App Store アプリ |
| `bat/`, `git/`, `mise/`, `ssh/`, `tmux/`, `vim/`, `yazi/`, `zsh/` | Stow パッケージ。各ディレクトリが `$HOME` 配下のパスを反映 |

### Stow パッケージマップ

| ディレクトリ | リンク先 |
|--------------|---------|
| `bat/` | `~/.config/bat/config` |
| `brew/` | `~/.Brewfile` |
| `git/` | `~/.gitconfig` |
| `mise/` | `~/.config/mise/config.toml` |
| `ssh/` | `~/.ssh/config` |
| `tmux/` | `~/.tmux.conf` |
| `vim/` | `~/.vimrc`, `~/.vim/` |
| `yazi/` | `~/.config/yazi/` |
| `zsh/` | `~/.zshrc` |

## セットアップフロー

### `bootstrap.sh`
クリーン macOS 用。private repo を clone するための準備までやる。

1. Homebrew をインストール (Xcode Command Line Tools = `git` も同時に入る)
2. `gh` CLI をインストールし、`gh auth login` で GitHub 認証
3. private dotfiles repo を `~/dotfiles` に clone
4. `setup.sh` に処理を引き継ぐ

### `setup.sh`
clone 済みの repo から実行する。冪等なので何度走らせても安全。

1. `brew bundle --file brew/.Brewfile` で全パッケージ入れる (`mise` 本体含む)
2. TPM (tmux plugin manager) を clone
3. repo-local git hooks を有効化 (`core.hooksPath = .githooks`)
4. `stow bat git mise ssh tmux vim yazi zsh` でシンボリックリンク作成
5. `mise install` で `mise/.config/mise/config.toml` にピン留めされたツール (Node、`codex`、`gemini-cli` など) をまとめてインストール

stow は `mise install` より先に走ります。これは mise が `~/.config/mise/config.toml` を読むタイミングで stow 経由の symlink が存在している必要があるためです。

## GitHub Gist について

このリポジトリは private なので、新 mac から直接 `curl` できません。そのため `bootstrap.sh` だけは public Gist にミラーしています。

- **ソース**: この repo の `bootstrap.sh`
- **公開コピー**: Gist `a5c4129e41cf20af06b6fbe2866d0248`

両者の同期は `.githooks/post-commit` が自動で行うので、`bootstrap.sh` を編集して `git commit` するだけで Gist 側にも反映されます。手動操作は不要です。

## Stow の使い方

```sh
stow <package>      # シンボリックリンク作成
stow -D <package>   # シンボリックリンク削除
stow -R <package>   # 再リンク (リフレッシュ)
```

## 注意事項

- 秘密鍵 (`id_ed25519`, `id_ed25519.pub`) と `.DS_Store` は `.gitignore` で除外
- tmux prefix は `Ctrl-\` (デフォルトの `Ctrl-b` ではない)
- ロケールは `ja_JP.UTF-8`
