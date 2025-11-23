//+------------------------------------------------------------------+
//|                                         BollingerBandAlert.mq5 |
//|                                   Copyright 2024, Claude Code  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Claude Code"
#property version   "1.00"
#property description "ボリンジャーバンドの上下バンドに終値で触れたときに通知するEA"

//--- 入力パラメータ
input int    BB_Period = 20;        // ボリンジャーバンド期間
input double BB_Deviation = 2.0;    // ボリンジャーバンド偏差
input bool   EnableAlert = true;    // アラート有効
input bool   EnableNotification = true; // プッシュ通知有効
input bool   EnableEmail = false;   // メール通知有効

//--- グローバル変数
int ExtBBHandle = 0;
datetime ExtLastAlertTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // ボリンジャーバンドインジケーターハンドルを作成
   ExtBBHandle = iBands(_Symbol, _Period, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   
   if(ExtBBHandle == INVALID_HANDLE)
   {
      Print("ボリンジャーバンドインジケーターの作成に失敗しました");
      return(INIT_FAILED);
   }
   
   Print("ボリンジャーバンドアラートEAが開始されました");
   Print("設定: 期間=", BB_Period, ", 偏差=", BB_Deviation);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ExtBBHandle != INVALID_HANDLE)
      IndicatorRelease(ExtBBHandle);
      
   Print("ボリンジャーバンドアラートEAが終了しました");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 新しいバーでのみチェック
   if(!IsNewBar())
      return;
      
   CheckBollingerBandBreakout();
}

//+------------------------------------------------------------------+
//| 新しいバーかどうかをチェック                                        |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime LastBarTime = 0;
   datetime CurrentBarTime = iTime(_Symbol, _Period, 0);
   
   if(CurrentBarTime != LastBarTime)
   {
      LastBarTime = CurrentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| ボリンジャーバンドブレイクアウトをチェック                             |
//+------------------------------------------------------------------+
void CheckBollingerBandBreakout()
{
   // 最新の2本のローソク足の情報を取得
   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, 2, rates) != 2)
   {
      Print("価格データの取得に失敗しました");
      return;
   }
   
   // ボリンジャーバンドの値を取得
   double bb_upper[], bb_middle[], bb_lower[];
   
   if(CopyBuffer(ExtBBHandle, 1, 0, 2, bb_upper) != 2 ||   // 上バンド
      CopyBuffer(ExtBBHandle, 0, 0, 2, bb_middle) != 2 ||  // 中央線
      CopyBuffer(ExtBBHandle, 2, 0, 2, bb_lower) != 2)     // 下バンド
   {
      Print("ボリンジャーバンドデータの取得に失敗しました");
      return;
   }
   
   // 現在のローソク足（完成したもの）
   double current_close = rates[0].close;
   double current_upper = bb_upper[0];
   double current_lower = bb_lower[0];
   
   // 前のローソク足
   double prev_close = rates[1].close;
   double prev_upper = bb_upper[1];
   double prev_lower = bb_lower[1];
   
   // 上バンドタッチ（ブレイクアウト）のチェック
   if(current_close >= current_upper && prev_close < prev_upper)
   {
      string message = StringFormat(
         "%s %s: 終値がボリンジャーバンド上バンドに触れました！\n価格: %s\n上バンド: %s\n時間: %s",
         _Symbol,
         PeriodToString(_Period),
         DoubleToString(current_close, _Digits),
         DoubleToString(current_upper, _Digits),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
      );
      
      SendAlert("上バンドタッチ", message);
   }
   
   // 下バンドタッチ（ブレイクアウト）のチェック
   if(current_close <= current_lower && prev_close > prev_lower)
   {
      string message = StringFormat(
         "%s %s: 終値がボリンジャーバンド下バンドに触れました！\n価格: %s\n下バンド: %s\n時間: %s",
         _Symbol,
         PeriodToString(_Period),
         DoubleToString(current_close, _Digits),
         DoubleToString(current_lower, _Digits),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)
      );
      
      SendAlert("下バンドタッチ", message);
   }
}

//+------------------------------------------------------------------+
//| 時間足を文字列に変換                                               |
//+------------------------------------------------------------------+
string PeriodToString(ENUM_TIMEFRAMES period)
{
   switch(period)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| アラートを送信                                                    |
//+------------------------------------------------------------------+
void SendAlert(string title, string message)
{
   // 同じ時間に複数のアラートを送らないようにする
   datetime current_time = TimeCurrent();
   if(current_time == ExtLastAlertTime)
      return;
      
   ExtLastAlertTime = current_time;
   
   // コンソールに表示
   Print(message);
   
   // アラートダイアログ表示
   if(EnableAlert)
   {
      Alert(title + ": " + _Symbol + " " + PeriodToString(_Period));
   }
   
   // プッシュ通知
   if(EnableNotification)
   {
      string short_message = StringFormat(
         "%s %s: BB%sタッチ - 価格:%s",
         _Symbol,
         PeriodToString(_Period),
         title == "上バンドタッチ" ? "上" : "下",
         DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits)
      );
      
      SendNotification(short_message);
   }
   
   // メール通知
   if(EnableEmail)
   {
      SendMail("ボリンジャーバンドアラート: " + title, message);
   }
}