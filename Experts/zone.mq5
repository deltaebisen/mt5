//+------------------------------------------------------------------+
//|                                           ZoneDrawerEA.mq5      |
//|                         Supply and Demand Zone Drawing EA       |
//+------------------------------------------------------------------+
#property strict

//---- Input parameters
input int         InpLookbackBars             = 200;         // Lookback bars for scanning
input int         InpLeftBars                 = 5;           // Left bars for swing detection
input int         InpRightBars                = 5;           // Right bars for swing detection
input int         InpFutureBars               = 15;          // Future bars for zone projection
input double      InpMinRallyPoints           = 800.0;       // Minimum rally points for buy zones
input double      InpMinDropPoints            = 800.0;       // Minimum drop points for sell zones
input double      InpZoneHeightPoints         = 200.0;       // Zone height in points
input double      InpZonePaddingPoints        = 30.0;        // Zone padding in points
input double      InpMinSwingSize             = 300.0;       // Minimum swing size in points
input double      InpZoneMinDistance          = 1000.0;      // Minimum distance between zones in points
input double      InpBreakThreshold           = 0.5;        // Break threshold (0.5 = 50% of zone must be broken)
input int         InpBreakConfirmBars         = 2;          // Bars to confirm break
input color       InpBuyZoneColor             = clrLightPink;
input color       InpSellZoneColor            = clrLightBlue;
input int         InpMaxZones                 = 15;          // Maximum zones to display
input string      InpObjectPrefix             = "ZD_";       // Object prefix for zones

//---- Global variables
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_lastBarTime = 0;
   
   // Remove existing zone objects
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, InpObjectPrefix) == 0) // if prefix matches
         ObjectDelete(0, name);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Optionally remove zones on deinit
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only process on new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == g_lastBarTime)
      return;
      
   g_lastBarTime = currentBarTime;
   
   // Check for broken zones first
   CheckAndRemoveBrokenZones();
   
   ScanAndDrawZones();
}

//+------------------------------------------------------------------+
//| Scan and draw zones                                             |
//+------------------------------------------------------------------+
void ScanAndDrawZones()
{
   int bars = Bars(_Symbol, _Period);
   if(bars <= InpLeftBars + InpRightBars + InpFutureBars + 10)
      return;
      
   int maxShift = MathMin(bars - 1 - InpFutureBars - InpRightBars,
                         InpLookbackBars + InpFutureBars + InpRightBars);
                         
   int createdZones = CountExistingZones();
   
   // Scan from oldest to newest bars with larger steps to reduce zones
   for(int shift = maxShift; shift >= InpLeftBars + InpRightBars + InpFutureBars; shift -= 3)
   {
      if(createdZones >= InpMaxZones)
         break;
         
      // Check for swing low/high
      bool isSwingLow  = IsSwingLow(shift, InpLeftBars, InpRightBars);
      bool isSwingHigh = IsSwingHigh(shift, InpLeftBars, InpRightBars);
      
      // Buy zones
      if(isSwingLow)
      {
         if(HasStrongRally(shift) && IsValidZoneLocation(shift, true))
         {
            if(CreateZoneObject(shift, true))
               createdZones++;
         }
      }
      
      // Sell zones
      if(isSwingHigh)
      {
         if(HasStrongDrop(shift) && IsValidZoneLocation(shift, false))
         {
            if(CreateZoneObject(shift, false))
               createdZones++;
         }
      }
      
      if(createdZones >= InpMaxZones)
         break;
   }
}

//+------------------------------------------------------------------+
//| Check if zone location is valid (no overlapping zones nearby)  |
//+------------------------------------------------------------------+
bool IsValidZoneLocation(int shift, bool isBuy)
{
   double basePrice = isBuy ? iLow(_Symbol, _Period, shift) : iHigh(_Symbol, _Period, shift);
   
   // Check existing zones for proximity
   int total = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, InpObjectPrefix) != 0)
         continue;
         
      // Get zone price levels
      double price1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      double price2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
      double zoneLow = MathMin(price1, price2);
      double zoneHigh = MathMax(price1, price2);
      
      // Check distance
      double distance = MathAbs(basePrice - (zoneLow + zoneHigh) / 2) / _Point;
      if(distance < InpZoneMinDistance)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is swing low                                       |
//+------------------------------------------------------------------+
bool IsSwingLow(int shift, int left, int right)
{
   double price = iLow(_Symbol, _Period, shift);
   
   // Check minimum swing size
   double swingHigh = price;
   for(int i = 1; i <= left; i++)
   {
      if(shift + i >= Bars(_Symbol, _Period))
         return false;
      double checkPrice = iLow(_Symbol, _Period, shift + i);
      if(price > checkPrice)
         return false;
      // Find highest point in left side for swing size calculation
      double highPrice = iHigh(_Symbol, _Period, shift + i);
      if(highPrice > swingHigh)
         swingHigh = highPrice;
   }
   
   // Check right side and find swing size
   for(int i = 1; i <= right; i++)
   {
      if(shift - i < 0)
         return false;
      double checkPrice = iLow(_Symbol, _Period, shift - i);
      if(price >= checkPrice)
         return false;
      // Find highest point in right side for swing size calculation
      double highPrice = iHigh(_Symbol, _Period, shift - i);
      if(highPrice > swingHigh)
         swingHigh = highPrice;
   }
   
   // Check minimum swing size
   double swingSize = (swingHigh - price) / _Point;
   if(swingSize < InpMinSwingSize)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is swing high                                      |
//+------------------------------------------------------------------+
bool IsSwingHigh(int shift, int left, int right)
{
   double price = iHigh(_Symbol, _Period, shift);
   
   // Check minimum swing size
   double swingLow = price;
   for(int i = 1; i <= left; i++)
   {
      if(shift + i >= Bars(_Symbol, _Period))
         return false;
      double checkPrice = iHigh(_Symbol, _Period, shift + i);
      if(price < checkPrice)
         return false;
      // Find lowest point in left side for swing size calculation
      double lowPrice = iLow(_Symbol, _Period, shift + i);
      if(lowPrice < swingLow)
         swingLow = lowPrice;
   }
   
   // Check right side and find swing size
   for(int i = 1; i <= right; i++)
   {
      if(shift - i < 0)
         return false;
      double checkPrice = iHigh(_Symbol, _Period, shift - i);
      if(price <= checkPrice)
         return false;
      // Find lowest point in right side for swing size calculation
      double lowPrice = iLow(_Symbol, _Period, shift - i);
      if(lowPrice < swingLow)
         swingLow = lowPrice;
   }
   
   // Check minimum swing size
   double swingSize = (price - swingLow) / _Point;
   if(swingSize < InpMinSwingSize)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if swing low has strong rally after                      |
//+------------------------------------------------------------------+
bool HasStrongRally(int shift)
{
   int start = MathMax(0, shift - InpFutureBars);
   int end   = shift - 1;
   if(end <= start)
      return false;
      
   double maxHigh = iHigh(_Symbol, _Period, start);
   for(int i = start + 1; i <= end; i++)
      if(iHigh(_Symbol, _Period, i) > maxHigh)
         maxHigh = iHigh(_Symbol, _Period, i);
         
   double diffPts = (maxHigh - iLow(_Symbol, _Period, shift)) / _Point;
   return (diffPts >= InpMinRallyPoints);
}

//+------------------------------------------------------------------+
//| Check if swing high has strong drop after                      |
//+------------------------------------------------------------------+
bool HasStrongDrop(int shift)
{
   int start = MathMax(0, shift - InpFutureBars);
   int end   = shift - 1;
   if(end <= start)
      return false;
      
   double minLow = iLow(_Symbol, _Period, start);
   for(int i = start + 1; i <= end; i++)
      if(iLow(_Symbol, _Period, i) < minLow)
         minLow = iLow(_Symbol, _Period, i);
         
   double diffPts = (iHigh(_Symbol, _Period, shift) - minLow) / _Point;
   return (diffPts >= InpMinDropPoints);
}

//+------------------------------------------------------------------+
//| Create zone rectangle object                                   |
//+------------------------------------------------------------------+
bool CreateZoneObject(int shift, bool isBuy)
{
   string typeStr = isBuy ? "BUY_" : "SELL_";
   string name = InpObjectPrefix + typeStr + IntegerToString((int)iTime(_Symbol, _Period, shift));
   
   // Check if object already exists
   if(ObjectFind(0, name) >= 0)
      return false;
      
   double basePrice = isBuy ? iLow(_Symbol, _Period, shift) : iHigh(_Symbol, _Period, shift);
   
   double pad       = InpZonePaddingPoints * _Point;
   double h         = InpZoneHeightPoints  * _Point;
   
   double price1, price2;
   if(isBuy)
   {
      price1 = basePrice - pad;       // Lower edge
      price2 = basePrice + h;         // Upper edge
   }
   else
   {
      price1 = basePrice + pad;       // Upper edge
      price2 = basePrice - h;         // Lower edge
   }
   
   datetime timeLeft  = iTime(_Symbol, _Period, shift);
   datetime timeRight = iTime(_Symbol, _Period, 0);     // Current time for right edge
   
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeLeft, price1, timeRight, price2))
      return false;
      
   ObjectSetInteger(0, name, OBJPROP_COLOR,       isBuy ? InpBuyZoneColor : InpSellZoneColor);
   ObjectSetInteger(0, name, OBJPROP_BACK,        true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,       1);
   ObjectSetInteger(0, name, OBJPROP_STYLE,       STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_FILL,        true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,      false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
   
   return true;
}

//+------------------------------------------------------------------+
//| Count existing zone objects                                    |
//+------------------------------------------------------------------+
int CountExistingZones()
{
   int total = ObjectsTotal(0, -1, -1);
   int count = 0;
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, InpObjectPrefix) == 0)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check and remove broken zones                                   |
//+------------------------------------------------------------------+
void CheckAndRemoveBrokenZones()
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, InpObjectPrefix) != 0)
         continue;
         
      if(IsZoneBroken(name))
      {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Check if zone is broken                                         |
//+------------------------------------------------------------------+
bool IsZoneBroken(string zoneName)
{
   // Get zone price levels
   double price1 = ObjectGetDouble(0, zoneName, OBJPROP_PRICE, 0);
   double price2 = ObjectGetDouble(0, zoneName, OBJPROP_PRICE, 1);
   double zoneLow = MathMin(price1, price2);
   double zoneHigh = MathMax(price1, price2);
   
   // Determine if this is a buy or sell zone
   bool isBuyZone = (StringFind(zoneName, "BUY_") >= 0);
   
   // Calculate break threshold
   double zoneRange = zoneHigh - zoneLow;
   double breakLevel;
   
   if(isBuyZone)
   {
      // For buy zones, check if price breaks below the zone
      breakLevel = zoneLow + (zoneRange * InpBreakThreshold);
   }
   else
   {
      // For sell zones, check if price breaks above the zone
      breakLevel = zoneHigh - (zoneRange * InpBreakThreshold);
   }
   
   // Check recent bars for break confirmation
   int barsToCheck = InpBreakConfirmBars;
   int breakCount = 0;
   
   for(int i = 1; i <= barsToCheck; i++)
   {
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      
      if(isBuyZone)
      {
         // Buy zone broken if price closes below break level
         double close = iClose(_Symbol, _Period, i);
         if(close < breakLevel)
            breakCount++;
      }
      else
      {
         // Sell zone broken if price closes above break level
         double close = iClose(_Symbol, _Period, i);
         if(close > breakLevel)
            breakCount++;
      }
   }
   
   // Zone is broken if it was broken for the required number of bars
   return (breakCount >= InpBreakConfirmBars);
}
//+------------------------------------------------------------------+