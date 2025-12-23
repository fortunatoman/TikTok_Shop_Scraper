# Quick Start Guide

Get up and running in 5 minutes (after prerequisites are installed).

## Prerequisites Check

```bash
# Check Ruby version (need 3.1+)
ruby --version

# Check Rails (will install if needed)
rails --version

# Check Node.js (need 16+)
node --version

# Check PostgreSQL
psql --version
```

## 1. Install Dependencies

```bash
# Ruby gems
bundle install

# Node.js packages
cd app/javascript && npm install && cd ../..
```

## 2. Download Encryption Files

**CRITICAL:** Download these files:
- https://github.com/justbeluga/tiktok-web-reverse-engineering/tree/main/encryption/xbogus.mjs
- https://github.com/justbeluga/tiktok-web-reverse-engineering/tree/main/encryption/xgnarly.mjs

Place in `app/javascript/encryption/` (replace placeholders).

## 3. Database Setup

```bash
rails db:create
rails db:migrate
```

## 4. Get TikTok Shop Credentials

1. Log into TikTok Shop Seller Center
2. Open DevTools (F12) → Network tab
3. Go to Product Analytics page
4. Find request to `/api/v2/insights/seller/ttp/product/list/v2`
5. Copy:
   - Cookie header
   - `oec_seller_id` from URL
   - `fp=verify_...` from URL (or `s_v_web_id` cookie)

## 5. Create .env File

```bash
cat > .env << EOF
TIKTOK_SHOP_COOKIE=your_cookie_here
TIKTOK_SHOP_OEC_SELLER_ID=your_seller_id_here
TIKTOK_SHOP_BASE_URL=https://seller-us.tiktok.com
TIKTOK_SHOP_FP=your_fp_here
EOF
```

## 6. Create Shop Record

```bash
rails console
```

```ruby
TikTokShop.create!(
  name: "My Shop",
  oec_seller_id: ENV['TIKTOK_SHOP_OEC_SELLER_ID'],
  cookie: ENV['TIKTOK_SHOP_COOKIE'],
  base_url: ENV['TIKTOK_SHOP_BASE_URL'] || "https://seller-us.tiktok.com",
  fp: ENV['TIKTOK_SHOP_FP'],
  timezone_offset: -28800
)
```

## 7. Test Sync

```ruby
# In Rails console
TikTokShop::SyncProductAnalytics.call(
  tik_tok_shop_id: 1,
  start_date: Date.today,
  end_date: Date.today
)
```

## 8. Start Server & Test API

```bash
# Terminal 1
rails server

# Terminal 2
curl "http://localhost:3000/api/v1/tik_tok_shops/1/product_analytics?start_date=2025-12-17&end_date=2025-12-17"
```

## Common Issues

| Issue | Solution |
|-------|----------|
| "Node.js not found" | Install Node.js 16+ |
| "Encryption files not found" | Download from GitHub repo |
| "Database connection error" | Check PostgreSQL is running |
| "Invalid token" | Verify encryption files are correct |
| "Shop not found" | Create TikTokShop record first |

## Next Steps

- See `SETUP.md` for detailed setup
- See `MANUAL_STEPS.md` for required actions
- See `README.md` for full documentation

