# GPTTrader V4 - Advanced AI News & Social Sentiment Trading Bot

GPTTrader V4 combines real-time news analysis with social media sentiment tracking. It features sophisticated content weighting, engagement-based impact scoring, and enhanced decision-making that distinguishes between real market actions and speculative predictions.

## 🆕 What's New in V4

### Enhancements

1. **High Accuracy News/Twitter/Social Media Integration**
   - Real-time Twitter/X post analysis from the X/twitter firehose.
   - Real-time high coverage news ingestion.

2. **Advanced Sentiment Weighting System**
   - Distinguishes between REAL ACTIONS vs PREDICTIONS/OPINIONS
   - External analyst sentiment treated as minority input (30% weight)
   - Your own content analysis carries majority weight (70%)
   - Content type multipliers (Real: 1.0x, Analytical: 0.5-0.7x, Speculative: 0.3x)

3. **Markdown-Based Data Format**
   - Clean, structured markdown formatting for all data
   - Improved readability and parsing
   - Better separation of news articles and social media posts

4. **Sophisticated Content Analysis**
   - Support for gpt-5
   - Reporting voice weighting (Investigative > Analytical > Explanatory)
   - Speculative phrase detection ("could", "might", "experts predict")
   - ICO/presale promotion filtering
   - Technical analysis opinion capping

## 📚 Core Architecture

### GPTTraderV4.py Components

#### 1. **Enhanced Initialization**
```python
class GPTTraderV4(IFreqaiModel):
    def __init__(self, **kwargs):
        # New configuration options
        self.gpt_config = GPTTraderConfig(
            use_news=True,          # Enable news analysis (included with $40/month sponsorship tier)
            use_twitter=False,       # Enable Twitter analysis (included with $100/month sponsorship tier)
            tweet_minutes=15,       # Twitter lookback period
            # ... other configs
        )
```

#### 2. **Dual Data Source Management**

**News Fetching** (`_prepare_latest_news`):
- Fetches crypto news via AskNews API
- Maintains rolling window of latest articles
- Returns markdown-formatted news with metadata

**Twitter Fetching** (`_prepare_latest_twitter`):
- Searches Twitter/X firehose for high accuracy project mentions
- Extracts engagement metrics from posts
- Filters by recency and relevance

#### 3. **Advanced Sentiment Calculation**

The new formula combines multiple factors:

```
Final_Sentiment = (Own_Analysis × 0.7) + (External_Sentiment × 0.3) 
                  × Content_Weight × Voice_Multiplier
```

Where:
- **Own_Analysis**: LLM's direct content analysis (70% weight)
- **External_Sentiment**: Pre-labeled sentiment from data provider (30% weight)
- **Content_Weight**: Real actions (1.0) vs Predictions (0.5-0.7) vs Speculation (0.3)
- **Voice_Multiplier**: Investigative (1.0) vs Analytical (0.6) vs Explanatory (0.4)

#### 4. **Engagement-Based Heat Scoring**

For social media posts:
```python
if total_engagement == 0:
    impact = 0  # No engagement = no market impact
else:
    impact = min(1.0, total_engagement / 100)
```

## 🎯 Sentiment Analysis Framework

### Content Type Classification

| Content Type | Weight | Example |
|-------------|--------|---------|
| **REAL ACTIONS** | 1.0x | "Grayscale files for Cardano ETF", "Exchange hacked", "Company buys $100M BTC" |
| **ANALYTICAL/PREDICTIVE** | 0.5-0.7x | "Technical pattern suggests", "Analysts predict", "Could reach $X" |
| **SPECULATIVE/PROMOTIONAL** | 0.3x | "Might provide 50x returns", "ICO could be next big thing" |

### Reporting Voice Impact

| Voice Type | Multiplier | Description |
|-----------|------------|-------------|
| **Investigative** | 1.0x | Factual reporting of actual events |
| **Analytical** | 0.6x | Analysis, predictions, technical patterns |
| **Explanatory** | 0.4x | Educational content, opinion pieces |

### Real-World Examples

1. **"Experts predict $0.009 coin could provide 50x return"** (Analytical voice)
   - Your analysis: 0.2 (speculative ICO)
   - External sentiment: 1.0 (overly optimistic)
   - Combined: (0.2 × 0.7) + (1.0 × 0.3) = 0.44
   - After multipliers: 0.44 × 0.6 × 0.3 = **0.08** ✅

2. **"Grayscale files for Cardano ETF"** (Investigative voice)
   - Your analysis: 0.9 (real filing)
   - External sentiment: 1.0 (agrees)
   - Combined: (0.9 × 0.7) + (1.0 × 0.3) = 0.93
   - After multipliers: 0.93 × 1.0 × 1.0 = **0.93** ✅

## 📊 Data Format

### News Article Format
```markdown
#### News#0
- Title: Bitcoin reaches new all-time high
- Published: 2025-08-18 14:38 (135 min ago)
- Source: FinanzNachrichten.de
- Classification: Finance
- External Analyst Sentiment: 1
- Reporting voice: Investigative
- Continent: North America
- Summary:
  Bitcoin has reached a new all-time high...
```

### Tweet/Social Media Format
```markdown
#### Tweet#0
- Title: X post from Crypto Trader
- Published: 2025-08-18 17:58 (5 min ago)
- Source: X (Twitter)
- Content:
  $BTC bullish pattern forming...
- Metrics: retweets=156, likes=423, replies=28, quotes=12
```

## ⚙️ Configuration

### Essential Configuration
```json
{
    "freqai": {
        "enabled": true,
        "live_retrain_hours": 0.05,
        "identifier": "gpttrader-v4",
        "GPTTrader": {
            "use_news": true,           // Enable news analysis (included with $40/month sponsorship tier)
            "use_twitter": false,         // Enable Twitter analysis (included with $100/month sponsorship tier)
            "news_hours": 1,            // News lookback period
            "tweet_minutes": 30,        // Twitter lookback period
            "news_count": 5,            // Number of items to analyze
            "target_profit": 0.03,      // 3% profit target
            "target_duration": 100,     // Max position duration
            "stoploss": 0.04,           // 4% stop loss
            "llm_model": "gpt-5",
            "llm_api_key": "YOUR_API_KEY",
            "ask_news_client_id": "YOUR_CLIENT_ID",
            "ask_news_client_secret": "YOUR_SECRET"
        }
    }
}
```

### New Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `use_news` | Enable news article analysis | true |
| `use_twitter` | Enable Twitter/social media analysis | false |
| `tweet_minutes` | Minutes to look back for tweets | 30 |

## 🧠 Decision Logic

### Entry Decision Framework

The system evaluates multiple factors before entering a position:

1. **Content Analysis**
   - Separates real actions from predictions
   - Applies appropriate weight multipliers
   - Caps speculative content impact

2. **Engagement Metrics** (for social media)
   - Zero engagement = zero impact
   - High engagement amplifies sentiment
   - Viral content gets priority

3. **Heat Score Calculation**
   ```
   Heat = (Recency × 0.4) + (Impact × 0.6)
   ```
   - Recency: Time decay from publication
   - Impact: Engagement metrics or news importance

4. **Final Decision**
   - LONG_ENTER: Sentiment > 0.4 AND Heat > 0.6
   - SHORT_ENTER: Sentiment < -0.4 AND Heat > 0.6
   - NEUTRAL: Otherwise

### Exit Decision Framework

#### Immediate Exit Conditions
- **LONG positions**: Exit if average sentiment < -0.2
- **SHORT positions**: Exit if average sentiment > 0.2
- Any sentiment reversal against position

#### Additional Exit Triggers
- High-heat news opposing position (heat > 0.7)
- Target profit reached
- Stop loss hit
- Maximum duration exceeded

## 🏃 Running GPTTrader V4

### Installation
```bash
# Install dependencies
pip install instructor asknews-sdk pydantic

# Copy files
cp GPTStrategyV4.py user_data/strategies/
cp GPTTraderV4.py user_data/freqaimodels/
```

### Dry Run Mode
```bash
freqtrade trade \
  --config user_data/config_gpttrader_v4.json \
  --strategy GPTStrategyV4 \
  --freqaimodel GPTTraderV4
```

### Live Trading
```bash
# Set dry_run to false in config
# Add exchange API keys
freqtrade trade \
  --config user_data/config_gpttrader_v4.json \
  --strategy GPTStrategyV4 \
  --freqaimodel GPTTraderV4
```

## 📈 Performance Optimizations

### API Call Efficiency
- Caches recent news and tweets
- Only fetches new content since last check
- Skips LLM calls when no fresh content

### Sentiment Accuracy
- Reduces false positives from speculative content
- Properly weights real events vs opinions
- Filters promotional/biased content

### Risk Management
- Immediate exit on sentiment reversal
- Multi-factor position evaluation
- Capital preservation prioritized

## 🔧 Customization Guide

### Adjust Sentiment Weights
Edit the formula in `GPTTraderV4.py`:
```python
# Change the 70/30 split between own analysis and external sentiment
Final_Sentiment = (Own_Analysis × 0.8) + (External_Sentiment × 0.2)
```

### Modify Content Type Weights
```python
# Adjust multipliers for different content types
REAL_ACTIONS = 1.0        # Keep at 1.0 for real events
ANALYTICAL = 0.6          # Increase/decrease for predictions
SPECULATIVE = 0.2         # Adjust for promotional content
```

### Customize Engagement Thresholds
```python
# Modify engagement impact calculation
if total_engagement < 10:
    impact = 0.1  # Very low impact
elif total_engagement < 100:
    impact = 0.5  # Medium impact
else:
    impact = 1.0  # High impact
```

## 🐛 Troubleshooting

### Common Issues

1. **"No tweets found"**
   - Verify Twitter API access via AskNews (only available with $100/month sponsorship tier)
   - Check if queries are properly formatted
   - Ensure domains include "https://x.com"

2. **"Sentiment seems off"**
   - Check External Analyst Sentiment values
   - Verify content type detection is working
   - Review voice multipliers

3. **"Too many false signals"**
   - Increase heat threshold (> 0.6)
   - Adjust sentiment thresholds
   - Enable more aggressive filtering

### Debug Mode
```python
# Enable detailed logging
logger.setLevel(logging.DEBUG)

# Log sentiment calculations
logger.debug(f"Own analysis: {own_analysis}")
logger.debug(f"External sentiment: {external}")
logger.debug(f"Content weight: {content_weight}")
logger.debug(f"Voice multiplier: {voice_mult}")
logger.debug(f"Final sentiment: {final}")
```

## 📊 Monitoring & Analysis

### Key Metrics to Track
- Sentiment accuracy vs actual price movement
- Heat score correlation with volatility
- Engagement metrics vs market impact
- False positive/negative rates

### FreqUI Dashboard
Monitor these custom indicators:
- `sentiment`: Current average sentiment
- `heat`: Current average heat score
- `expert_long_enter/exit`: Long signals
- `expert_short_enter/exit`: Short signals
- `sentiment_yes/no/unknown`: News distribution

## 🚀 Advanced Features

### Multi-Source Weighting
The system intelligently combines:
- Traditional news articles (higher credibility)
- Social media posts (faster reaction time)
- Engagement metrics (crowd validation)
- External analyst opinions (minority input)

### Speculative Content Filtering
Automatically detects and reduces impact of:
- ICO/presale promotions
- "Could be" predictions
- Technical analysis opinions
- Comparison to historical patterns

### Real-Time Adaptation
- Adjusts to news velocity
- Responds to viral social content
- Prioritizes breaking news
- Filters old/stale information

## 📝 Important Notes

- **API Costs**: Each analysis uses LLM tokens - monitor usage (stick to 15m and 30m timeframe. Each candle/coin requires tokens/requests).
- **Data Quality**: Performance depends on news/tweet availability for the specific coin.
- **Market Conditions**: Works best in news-driven markets
- **Risk Warning**: This is advanced experimental trading - start small

## 🤝 Support & Contributing

- FreqAI Discord: https://discord.gg/KdcGN87q5U
- GitHub Issues: [Tag with `gpttrader-v4`](https://github.com/emergentmethods/sponsor-files/issues)
- Feature Requests: [Open a discussion](https://github.com/emergentmethods/sponsor-files/issues)

## 📄 License

Released to FreqAI sponsors. Support the project:
https://github.com/sponsors/robcaulk
