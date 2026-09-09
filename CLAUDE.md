# AWS SAAクエスト(aws-saa-quest)プロジェクト概要

## アプリの目的
AWS Certified Solutions Architect - Associate(SAA-C03)試験の合格を目指す学習アプリ。
4択問題の出題・採点・解説に加え、RPG風のレベル可視化でモチベーションを維持する。
UI は姉妹プロジェクト sc-study-app(情報処理安全確保支援士版)と共通で、出題データのみ AWS SAA に差し替えている。

## 開発上の制約・方針
- **完全無料構成にこだわる**: GitHub Pages(静的ホスティング) + Supabase(無料枠)のみで運用する
- Claude API(従量課金)は使わない。解説の深掘りは、開発者が Claude.ai / ChatGPT に問題を貼り付けて別途対応する運用(アプリはプロンプト生成と回答の保存のみ担当)
- ビルドツール(React/npm build等)は使わず、単一の `index.html` に HTML/CSS/JS をすべて記述する
  - 理由: 開発者は iPhone(Safari)のみで開発することも多く、Node.js/npm のビルド環境に依存しない構成が必須
- supabase-js は CDN 経由(`<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2">`)で読み込む

## 技術構成
- フロントエンド: GitHub Pages(https://ichiroumakku.github.io/aws-saa-quest/)
- バックエンド: Supabase(プロジェクト名: aws-saa-quest, リージョン: Tokyo)
  - Project URL / anon key は `index.html` 冒頭に直書き(公開可能な publishable key)
  - 認証: Supabase Auth(メール/パスワード、Confirm email は OFF 設定)
  - スキーマ定義は `schema.sql`。トリガー・関数は使わない

## データベース構成(Supabase)
- `profiles`: user_id, display_name(表示名、ランキング用)
- `questions`: id, exam_type(D1〜D4 = SAA-C03 のドメイン), year(生成バッチ), question_no, field_tags(配列), difficulty(1=基礎/2=中間/3=本番同等), body, choices(jsonb), official_answer, explanation, source(sample/generated)
- `field_status`: user_id, field_id, level, exp, mastery_rate(分野別のレベル・EXP管理)
- `answer_logs`: user_id, question_id, user_answer, is_correct, exp_gained(回答履歴)
- `chat_messages`: 解説の深掘り学習で使用。疑問(role:user)と貼り付けた回答(role:assistant)をペアで保存
- `leaderboard`: view。profiles と field_status を集計したランキング用ビュー(security_invoker=true)

## レベル/キャラクター(index.html内)
- 総合レベル = 全分野の field_status.exp 合計から算出。Lv N→N+1 に必要なEXP = 100 + 20*(N-1)
- Lv30 ≒ 本試験合格ライン(累計 約11,000 EXP)。※ SAA 向けの調整余地あり
- Lv帯(5刻み)で装備が変わるゆるキャラをインラインSVGで表示(heroSvg関数、7段階)

### RLS(Row Level Security)方針
- 閲覧: `questions` は認証済み全員、`field_status` と `profiles` も認証済み全員(ランキング表示のため)、`answer_logs` と `chat_messages` は本人のみ
- 書き込み: すべて本人のデータのみ。`questions` への投入は SQL Editor(サービスロール)で行う

## 出題分野タグ(11分野)
SAA-C03 の4ドメイン(D1 セキュア設計 / D2 弾力性のある設計 / D3 高性能設計 / D4 コスト最適化設計)を、
サービス領域ベースの11タグに細分化して管理する。
- `compute`: コンピューティング(EC2 / Lambda / ECS・Fargate / Auto Scaling)
- `storage`: ストレージ(S3 / EBS / EFS / FSx / Storage Gateway)
- `database`: データベース(RDS / Aurora / DynamoDB / ElastiCache / Redshift)
- `network`: ネットワーキング(VPC / Route 53 / CloudFront / ELB / Direct Connect / Global Accelerator)
- `security`: セキュリティ・IAM(IAM / KMS / Secrets Manager / WAF / Shield / Cognito)
- `resilience`: 信頼性・高可用性(Multi-AZ / バックアップ / DR / RTO・RPO)
- `performance`: パフォーマンス最適化(キャッシュ / リードレプリカ / インスタンス選定)
- `cost`: コスト最適化(Savings Plans / スポット / S3 ストレージクラス / 適正化)
- `integration`: アプリ統合・疎結合(SQS / SNS / EventBridge / Step Functions / API Gateway)
- `monitoring`: 監視・運用管理(CloudWatch / CloudTrail / X-Ray / Systems Manager)
- `migration`: 移行・データ転送(DMS / Snow Family / DataSync / Migration Hub)

## 問題データの生成フロー(tools/)
1. `tools/input/batch-XXX.json` に問題を記述(`c` 配列の先頭を正答とする簡易形式)
2. `node tools/build-batch.js batch-XXX` で ア/イ/ウ/エ の正答分布を均等化しつつ INSERT 文を生成 → `tools/out/`
3. 生成された SQL を Supabase の SQL Editor で実行
