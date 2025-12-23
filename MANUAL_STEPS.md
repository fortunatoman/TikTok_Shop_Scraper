# Manual Steps Required

This document lists the steps you need to complete manually to get the application running.

## 1. Download Encryption Files

The encryption files are **required** for the TikTok Shop API to work. They are not included in this repository for legal/licensing reasons.

**Action Required:**
1. Visit: https://github.com/justbeluga/tiktok-web-reverse-engineering/tree/main/encryption
2. Download `xbogus.mjs` and `xgnarly.mjs`
3. Replace the placeholder files in `app/javascript/encryption/`:
   - `app/javascript/encryption/xbogus.mjs` (replace placeholder)
   - `app/javascript/encryption/xgnarly.mjs` (replace placeholder)

**Current Status:** Placeholder files exist but need to be replaced with actual implementations.

## 2. Install Dependencies

**Action Required:**

```bash
# Install Ruby gems
bundle install

# Install Node.js packages
cd app/javascript
npm install
cd ../..
```

## 3. Set Up Database

**Action Required:**

```bash
# Create PostgreSQL database
rails db:create

# Run migrations
rails db:migrate
```

**Note:** Ensure PostgreSQL is installed and running.

## 4. Configure Environment Variables

**Action Required:**

Create a `.env` file in the root directory with:

```bash
TIKTOK_SHOP_COOKIE=your_cookie_string_here
TIKTOK_SHOP_OEC_SELLER_ID=your_seller_id_here
TIKTOK_SHOP_BASE_URL=https://seller-us.tiktok.com
TIKTOK_SHOP_FP=your_fingerprint_here
```

**How to get these values:**
1. Log into TikTok Shop Seller Center
2. Open browser DevTools (F12)
3. Go to Network tab
4. Navigate to Product Analytics page
5. Find a request to `/api/v2/insights/seller/ttp/product/list/v2`
6. Copy:
   - `Cookie` header → `TIKTOK_SHOP_COOKIE`
   - `oec_seller_id` from URL → `TIKTOK_SHOP_OEC_SELLER_ID`
   - `fp=verify_...` from URL or `s_v_web_id` cookie → `TIKTOK_SHOP_FP`

## 5. Create TikTok Shop Record

**Action Required:**

In Rails console:

```ruby
rails console

TikTokShop.create!(
  name: "My Shop",
  oec_seller_id: ENV['TIKTOK_SHOP_OEC_SELLER_ID'] || "7496020242935155064",
  cookie: ENV['TIKTOK_SHOP_COOKIE'],
  base_url: ENV['TIKTOK_SHOP_BASE_URL'] || "https://seller-us.tiktok.com",
  fp: ENV['TIKTOK_SHOP_FP'],
  timezone_offset: -28800
)
```

**Note:** Replace the values with your actual credentials.

## 6. Test the Setup

**Action Required:**

1. **Test the fetcher:**
```bash
echo '{"cookie":"YOUR_COOKIE","oecSellerId":"YOUR_SELLER_ID","baseUrl":"https://seller-us.tiktok.com","fp":"YOUR_FP","timezoneOffset":-28800,"startDate":"2025-12-17","endDate":"2025-12-17","pageNo":0,"pageSize":10}' | node app/javascript/products.mjs
```

2. **Test the sync service:**
```ruby
rails console
TikTokShop::SyncProductAnalytics.call(
  tik_tok_shop_id: 1,
  start_date: Date.today,
  end_date: Date.today
)
```

3. **Test the API:**
```bash
rails server
# In another terminal:
curl "http://localhost:3000/api/v1/tik_tok_shops/1/product_analytics?start_date=2025-12-17&end_date=2025-12-17"
```

## 7. Adjust Response Parsing (If Needed)

**Action Required (if API response structure differs):**

The sync service (`app/services/tik_tok_shop/sync_product_analytics.rb`) includes flexible parsing logic, but you may need to adjust it based on the actual API response structure.

**To debug:**
1. Add logging in `sync_product_analytics.rb`:
```ruby
Rails.logger.debug("API Response: #{response.inspect}")
```

2. Check the actual response structure
3. Adjust `extract_products_data` and `upsert_product_and_snapshot` methods accordingly

## Summary Checklist

- [ ] Download and replace encryption files (`xbogus.mjs`, `xgnarly.mjs`)
- [ ] Install Ruby dependencies (`bundle install`)
- [ ] Install Node.js dependencies (`npm install` in `app/javascript`)
- [ ] Set up PostgreSQL database
- [ ] Run migrations (`rails db:migrate`)
- [ ] Create `.env` file with credentials
- [ ] Create TikTokShop record in database
- [ ] Test fetcher manually
- [ ] Test sync service
- [ ] Test API endpoint
- [ ] Adjust response parsing if needed

## Troubleshooting

If you encounter issues:

1. **"Node.js not found"** → Install Node.js 16+
2. **"Encryption files not found"** → Download from GitHub repo
3. **"Database connection error"** → Check PostgreSQL is running
4. **"Request failed: Invalid token"** → Verify encryption files are correct
5. **"TikTok Shop not found"** → Create TikTokShop record first

See `SETUP.md` for more detailed troubleshooting.

