# aws-saa-quest

AWS Certified Solutions Architect - Associate (SAA-C03) 学習アプリ。
[sc-study-app](https://github.com/ichiroumakku/sc-study-app)(支援士クエスト)の UI をそのまま流用し、出題データを AWS SAA に差し替えたもの。

- フロント: GitHub Pages(単一 `index.html`、ビルドなし)
- バックエンド: Supabase 無料枠(Auth + Postgres)
- 公開 URL: https://ichiroumakku.github.io/aws-saa-quest/

## セットアップ

1. Supabase で新規プロジェクト `aws-saa-quest`(Tokyo / Confirm email OFF)を作成
2. SQL Editor で [`schema.sql`](schema.sql) を実行
3. `tools/out/` の seed SQL を実行して問題を投入
4. `index.html` の `__SUPABASE_URL__` / `__SUPABASE_ANON_KEY__` を新プロジェクトの値に置換
5. `main` へ push すると GitHub Pages に反映
