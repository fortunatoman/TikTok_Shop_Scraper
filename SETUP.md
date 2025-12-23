# Setup Guide

This guide will help you set up the TikTok Shop Product Analytics pipeline.

## Prerequisites

1. **Ruby 3.1+** - Install from [ruby-lang.org](https://www.ruby-lang.org/en/downloads/)
2. **Rails 7.0+** - Will be installed via Bundler
3. **PostgreSQL** - Install from [postgresql.org](https://www.postgresql.org/download/)
4. **Node.js 16+** - Install from [nodejs.org](https://nodejs.org/)

## Step-by-Step Setup

### 1. Install Ruby Dependencies

```bash
bundle install
```

### 2. Install JavaScript Dependencies

```bash
cd app/javascript
npm install
cd ../..
```

### 3. Set Up Encryption Files

The encryption files (`xbogus.mjs` and `xgnarly.mjs`) are required for generating TikTok API tokens.

**Download from:**
https://github.com/justbeluga/tiktok-web-reverse-engineering/tree/main/encryption

**Place them in:**
- `app/javascript/encryption/xbogus.mjs`
- `app/javascript/encryption/xgnarly.mjs`

**Note:** The placeholder files are currently in place. Replace them with the actual implementations.

### 4. Configure Database

Create the PostgreSQL database:

```bash
# Create database
createdb tiktok_shop_analytics_development

# Or let Rails create it
rails db:create
```

### 5. Run Migrations

```bash
rails db:migrate
```

### 6. Configure Environment Variables

Create a `.env` file in the root directory (or set environment variables):

```bash
# TikTok Shop credentials
TIKTOK_SHOP_COOKIE=your_cookie_string_here
TIKTOK_SHOP_OEC_SELLER_ID=your_seller_id_here
TIKTOK_SHOP_BASE_URL=https://seller-us.tiktok.com
TIKTOK_SHOP_FP=your_fingerprint_here
```

**To get the cookie:**
1. Log into TikTok Shop Seller Center
2. Open browser DevTools (F12)
3. Go to Network tab
4. Make a request to the Product Analytics page
5. Copy the `Cookie` header value

**To get the fingerprint (fp):**
- Look for `fp=verify_...` in the request URL or cookies
- It's the `s_v_web_id` cookie value

### 7. Create a TikTok Shop Record

In Rails console:

```ruby
rails console

TikTokShop.create!(
  name: "My Shop",
  oec_seller_id: "7496020242935155064",
  cookie: ENV['TIKTOK_SHOP_COOKIE'],
  base_url: "https://seller-us.tiktok.com",
  fp: ENV['TIKTOK_SHOP_FP'],
  timezone_offset: -28800
)
```

### 8. Test the Fetcher

Test the JavaScript fetcher directly:

```bash
# Create a test input file
echo '{"cookie":"YOUR_COOKIE","oecSellerId":"YOUR_SELLER_ID","baseUrl":"https://seller-us.tiktok.com","fp":"YOUR_FP","timezoneOffset":-28800,"startDate":"2025-12-17","endDate":"2025-12-17","pageNo":0,"pageSize":10}' | node app/javascript/products.mjs
```

### 9. Sync Product Data

In Rails console:

```ruby
rails console

# Sync a single day
TikTokShop::SyncProductAnalytics.call(
  tik_tok_shop_id: 1,
  start_date: Date.parse('2025-12-17'),
  end_date: Date.parse('2025-12-17')
)

# Sync a date range (backfill)
TikTokShop::SyncProductAnalytics.call(
  tik_tok_shop_id: 1,
  start_date: 30.days.ago.to_date,
  end_date: Date.today
)
```

### 10. Start the Rails Server

```bash
rails server
```

The API will be available at `http://localhost:3000`

### 11. Test the API

```bash
# Get product analytics
curl "http://localhost:3000/api/v1/tik_tok_shops/1/product_analytics?start_date=2025-12-17&end_date=2025-12-17"

# With GMV filter
curl "http://localhost:3000/api/v1/tik_tok_shops/1/product_analytics?start_date=2025-12-17&end_date=2025-12-17&min_gmv=1000"
```

## Troubleshooting

### "Node.js not found"
- Ensure Node.js is installed: `node --version`
- Add Node.js to your PATH if needed

### "Encryption files not found"
- Download `xbogus.mjs` and `xgnarly.mjs` from the GitHub repository
- Place them in `app/javascript/encryption/`

### "Database connection error"
- Ensure PostgreSQL is running
- Check `config/database.yml` settings
- Verify database exists: `rails db:create`

### "Request failed: Invalid token"
- Check that cookies are valid and not expired
- Verify X-Bogus/X-Gnarly generation is working
- Ensure encryption files are correct

### "TikTok Shop not found"
- Create a TikTokShop record first (see step 7)
- Verify the ID matches your record

## Next Steps

- Set up a background job processor (Sidekiq/ActiveJob) for scheduled syncing
- Add error monitoring (Sentry, etc.)
- Set up logging
- Add rate limiting for API requests

