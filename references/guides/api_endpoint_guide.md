# Free Tier API Endpoints Guide

This guide identifies genuinely free API endpoints for testing REST integrations without subscription barriers.

## OpenWeatherMap (Free Tier)

### **Confirmed Free APIs**
**Base URL**: `https://api.openweathermap.org`

**Current Weather** - `/data/2.5/weather`
- **Status**: Free with API key
- **Limits**: 60 calls/minute, 1M calls/month
- **Auth**: Query parameter `appid=your-api-key`
- **Data**: Current conditions, temperature, humidity, wind

**5-Day Forecast** - `/data/2.5/forecast`
- **Status**: Free with API key
- **Limits**: 60 calls/minute, 1M calls/month
- **Auth**: Query parameter `appid=your-api-key`
- **Data**: 5-day forecast with 3-hour intervals


**Air Pollution** - `/data/2.5/air_pollution`
- **Status**: Free with API key
- **Auth**: Query parameter `appid=your-api-key`

**Geocoding** - `/geo/1.0/direct`
- **Status**: Free with API key
- **Auth**: Query parameter `appid=your-api-key`

### **Requires Paid Subscription**
**One Call API 3.0** - `/data/3.0/onecall`
- **Status**: Requires "One Call by Call" subscription (not free)
- **Error**: "Please note that using One Call 3.0 requires a separate subscription"

**Hourly Forecast (Pro)** - Any `pro.openweathermap.org` endpoint
- **Status**: Requires paid PRO subscription

## Alternative Free APIs

### Open-Meteo (Completely Free)
**Base URL**: `https://api.open-meteo.com`

**Weather Forecast** - `/v1/forecast`
- **Status**: Completely free, no API key needed
- **Limits**: 10,000 calls/day (fair usage)
- **Auth**: None required
- **Data**: 16-day forecasts, hourly data, multiple weather models
- **Example**: `?latitude=52.52&longitude=13.41&current=temperature_2m,wind_speed_10m`

### JSONPlaceholder (Testing)
**Base URL**: `https://jsonplaceholder.typicode.com`

**Posts API** - `/posts`
- **Status**: Free fake REST API for testing
- **Auth**: None required
- **Use**: Perfect for testing REST connector setup

### httpbin (HTTP Testing)
**Base URL**: `https://httpbin.org`

**Echo Endpoints** - `/get`, `/post`, `/headers`
- **Status**: Free HTTP testing service
- **Auth**: Various test patterns available
- **Use**: Test different HTTP methods and authentication patterns

## Common Free Tier Patterns

### Authentication Methods (Free APIs)
1. **Query Parameter**: `?appid=key` (OpenWeatherMap)
2. **Header**: `X-API-Key: key` or `Authorization: Bearer key`
3. **No Auth**: Completely open (Open-Meteo, httpbin)

### Rate Limits (Typical)
- **OpenWeather**: 60/minute, 1M/month
- **Open-Meteo**: 10K/day
- **httpbin**: Unlimited

### Best Practices
1. **Start with no-auth APIs** for initial REST connector testing
2. **Use OpenWeather free tier** for realistic authentication testing
3. **Avoid pro/premium subdomains** unless confirmed paid subscription
4. **Check pricing pages** - "free tier" often has hidden subscription requirements

## Integration Examples

### Boomi REST Configuration Patterns

**OpenWeather Connection**:
```xml
<field id="url" type="string" value="https://api.openweathermap.org"/>
<field id="auth" type="string" value="NONE"/>
```

**OpenWeather Operation** (5-day forecast):
```xml
<field id="path" type="string" value="/data/2.5/forecast"/>
<field id="queryParameters" type="customproperties">
  <customProperties>
    <properties key="lat" value="44.34"/>
    <properties key="lon" value="10.99"/>
    <properties key="appid" value="your-api-key-here"/>
    <properties key="units" value="metric"/>
  </customProperties>
</field>
```

**Open-Meteo Connection** (no auth):
```xml
<field id="url" type="string" value="https://api.open-meteo.com"/>
<field id="auth" type="string" value="NONE"/>
```

## Troubleshooting Common Issues

### "401 Unauthorized" Errors
- **Check API key validity**: Test in browser or curl first
- **Verify free tier access**: Ensure endpoint doesn't require subscription
- **Check auth method**: Query param vs header placement

### "Subscription Required" Errors
- **Switch to basic endpoints**: Avoid `/pro/` subdomains
- **Use older API versions**: Often more permissive (2.5 vs 3.0)
- **Consider alternatives**: Open-Meteo for weather data

### Rate Limiting
- **Space out calls**: Don't exceed per-minute limits
- **Cache responses**: Avoid repeated identical calls
- **Use appropriate test data**: Don't spam production APIs during development

This guide should prevent the common trap of accidentally using paid API endpoints during development and testing phases.