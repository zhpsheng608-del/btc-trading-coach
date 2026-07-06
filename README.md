# BTC 中短线 AI 交易教练 — 自动化工作流

基于 Codex CLI + GitHub Actions + 钉钉机器人的全自动 BTC 交易分析系统。

## 系统架构

```
GitHub Actions (定时触发)
       │
       ▼
┌─ 脚本入口 ──────────────────────────────┐
│  scripts/run-btc-analysis.sh             │
│  （根据报告类型选择对应 prompt）          │
└────────────┬────────────────────────────┘
             │
     ┌───────┴───────┐
     ▼               ▼
fetch-btc-data.sh   prompts/*.md
（拉取行情数据）    （系统指令模板）
     │               │
     └───────┬───────┘
             ▼
┌─ Codex CLI ──────────────────────────────┐
│  codex exec -o report.md "prompt+data"   │
│  调用 AI 模型进行专业交易分析             │
└────────────┬────────────────────────────┘
             ▼
┌─ 输出 ──────────────────────────────────┐
│  reports/btc_*.md                        │
└────────────┬────────────────────────────┘
             ▼
┌─ 钉钉机器人 ────────────────────────────┐
│  send-to-dingtalk.sh → 钉钉群          │
└─────────────────────────────────────────┘
```

## 报告类型与触发时间

| 报告类型 | 触发时间 (CST) | 工作流文件 | 用途 |
|---|---|---|---|
| **每日晨报** 🗞️ | 每天 09:00 | `btc-morning-report.yml` | 完整市场分析、风险等级、交易建议 |
| **两小时更新** 🔄 | 11:00/13:00/15:00/17:00/19:00/21:00/23:00 | `btc-interval-update.yml` | 快速判断趋势是否变化 |
| **每周总结** 📊 | 周日 22:00 | `btc-weekly-report.yml` | 周度交易统计与总结 |

所有工作流同时支持 `workflow_dispatch` 手动触发。

## 前置准备

### 1. 必需的 Secrets / 环境变量

在 GitHub 仓库的 **Settings → Secrets and variables → Actions** 中添加：

| Secret | 说明 | 获取方式 |
|---|---|---|
| `OPENAI_API_KEY` | OpenAI API 密钥 | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| `DINGTALK_WEBHOOK_URL` | 钉钉机器人 Webhook URL | 钉钉群 → 群设置 → 智能群助手 → 添加自定义机器人 |
| `DINGTALK_SECRET` | 钉钉机器人签名密钥（可选） | 钉钉机器人安全设置中启用"加签" |

### 2. 钉钉机器人配置

1. 打开目标钉钉群 → 群设置 → 智能群助手 → 添加机器人
2. 选择 **自定义（通过 Webhook 接入）**
3. 安全设置推荐勾选 **加签**，将 `DINGTALK_SECRET` 填入 GitHub Secrets
4. 复制 Webhook URL，填入 `DINGTALK_SECRET`

### 3. 本地开发测试

```bash
# 1. 复制并填写环境变量
cp .env.example .env

# 2. 安装 Codex CLI
npm install -g @openai/codex

# 3. 确保 curl 和 python3 可用（用于数据获取和 JSON 处理）

# 4. 本地运行测试
export OPENAI_API_KEY=sk-xxx
export DINGTALK_WEBHOOK_URL=https://oapi.dingtalk.com/robot/send?access_token=xxx
export DINGTALK_SECRET=xxx

# 生成每日晨报
bash scripts/run-btc-analysis.sh morning

# 生成两小时更新
bash scripts/run-btc-analysis.sh interval

# 生成每周总结
bash scripts/run-btc-analysis.sh weekly
```

## 项目结构

```
├── .github/workflows/
│   ├── btc-morning-report.yml      # 每日晨报 (09:00 CST)
│   ├── btc-interval-update.yml     # 两小时更新 (11-23 CST)
│   └── btc-weekly-report.yml       # 每周总结 (周日 22:00 CST)
├── scripts/
│   ├── fetch-btc-data.sh           # 拉取 BTC 行情数据（公开 API）
│   ├── send-to-dingtalk.sh         # 发送 Markdown 到钉钉群
│   └── run-btc-analysis.sh         # 主调度脚本
├── prompts/
│   ├── morning-report.md           # 晨报系统提示模板
│   ├── interval-report.md          # 两小时更新提示模板
│   └── weekly-report.md            # 周报系统提示模板
├── reports/                        # 生成的报告输出目录
├── .env.example                    # 环境变量示例
└── README.md
```

## 数据源（公开 API，无需 Key）

| 数据 | API | 用途 |
|---|---|---|
| BTC 实时价格 / 24h 统计 | Binance Spot API | 价格、涨跌幅、成交量 |
| 日线 / 4小时 K 线 | Binance Klines API | 趋势分析、技术指标 |
| 资金费率 | Binance Futures API | 合约市场情绪 |
| 恐慌贪婪指数 | alternative.me | 市场情绪 |
| BTC 链上数据 | CoinGecko API | 市值、排名、链上指标 |

## 交易教练系统功能

- **周期判断**：三日线 > 日线 > 四小时多周期分析
- **风险等级**：⭐ ~ ⭐⭐⭐⭐⭐ 五档风险提示
- **关键位置**：压力位 / 支撑位 / 成交密集区 / 流动性区域
- **交易建议**：可操作时明确建议，否则严格提示等待
- **宏观日历**：自动检查美联储、CPI、非农等宏观事件
- **链上指标**：资金费率、多空比、恐慌贪婪指数
- **纪律训练 + 心理训练**：每日一条，重复强化
- **纪律检查**：每日自我评分（10 分制）
- **每周总结**：交易统计 + 能力评分 + 改进目标

## 核心原则

- **纪律 > 技术 > 盈利**
- **不要为了交易而交易**
- **今天最好的交易，就是不交易**
- **现金，也是仓位**
- **不确定，就是风险**

## 注意事项

- Codex CLI 在 CI 中运行时需要 `--dangerously-bypass-approvals-and-sandbox` 标志，因为 GitHub Actions runner 本身已是隔离环境
- 钉钉 Markdown 消息有 20000 字符限制，脚本会自动截断
- 所有 `reports/` 目录下的报告会保留为 GitHub Actions Artifact，可按需下载
