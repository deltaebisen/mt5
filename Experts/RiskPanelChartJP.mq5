#property strict
#property copyright "You"
#property link      ""
#property version   "1.02"
#property description "ロットと許容損失額(円)からSLを自動計算して成行発注するパネル + 最後/全ポジ決済 + SLライン表示 + 損益/時刻表示"

// UI
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>

// トレード
#include <Trade\Trade.mqh>

CTrade trade;

//---------------------------------------------------------
// パネルクラス
//---------------------------------------------------------
class CRiskPanel
{
private:
   CLabel  m_lblSymbol;    // シンボル表示
   CEdit   m_volume;       // ロット
   CEdit   m_risk;         // 損失額(円)
   CEdit   m_tp_profit;    // TP利益額(円)
   CButton m_buy;          // 買い
   CButton m_sell;         // 売り
   CButton m_closeLast;    // 最後のポジション決済
   CButton m_closeAll;     // 全ポジション決済（このシンボル）
   CLabel  m_lblPl;        // 最後のポジション損益
   CLabel  m_lblPlLabel;   // "Last P/L:" ラベル（白）
   CLabel  m_lblPlValue;   // 損益値（緑）
   CLabel  m_lblTime;      // 現在時刻(JST)
   CLabel  m_lblTimeLabel; // "Time (JST):" ラベル（白）
   CLabel  m_lblTimeValue; // 時刻値（緑）
   CLabel  m_msg;          // メッセージ表示

   string  m_usdJpySymbol; // ドル円シンボル名
   string  m_currentSymbol; // 現在表示中のシンボル
   
   long    m_chart_id;     // チャートID
   int     m_subwin;       // サブウィンドウ

public:
   CRiskPanel(const string usdJpySymbol = "USDJPY")
   {
      m_usdJpySymbol = usdJpySymbol;
   }

   // パネル作成
   bool Create(const long chart_id,
               const string name,
               const int subwin,
               const int x1,
               const int y1,
               const int x2,
               const int y2)
   {
      m_chart_id = chart_id;
      m_subwin = subwin;
      
      int left   = x1 + 10;
      int top    = 20;
      int width  = x2 - x1 - 20;
      int line_h = 20;
      int margin = 5;

      // シンボル表示
      m_lblSymbol.Create(m_chart_id, "lbl_symbol", m_subwin,
                         left, top, left+width, top+line_h);
      m_currentSymbol = _Symbol;  // 現在のシンボルを保存
      m_lblSymbol.Text(StringFormat("Symbol: %s", m_currentSymbol));
      m_lblSymbol.Color(clrLime);  // 緑色
      m_lblSymbol.FontSize(10);

      top += line_h + margin;

      // ロットラベル
      CLabel *lbl_vol = new CLabel;
      lbl_vol.Create(m_chart_id, "lbl_vol", m_subwin,
                     left, top, left+60, top+line_h);
      lbl_vol.Text("Lots");
      lbl_vol.Color(clrWhite);  // 白色ラベル
      lbl_vol.FontSize(9);

      // ロット入力
      m_volume.Create(m_chart_id, "edt_vol", m_subwin,
                      left+65, top-2, left+65+width-70, top+line_h+2);
      m_volume.Text("0.10");
      m_volume.Color(clrLime);  // 緑色値
      m_volume.ColorBackground(clrBlack);
      m_volume.ColorBorder(clrGray);  // グレー枠

      top += line_h + margin;

      // 損失額ラベル
      CLabel *lbl_risk = new CLabel;
      lbl_risk.Create(m_chart_id, "lbl_risk", m_subwin,
                      left, top, left+80, top+line_h);
      lbl_risk.Text("Risk (JPY)");
      lbl_risk.Color(clrWhite);  // 白色ラベル
      lbl_risk.FontSize(9);

      // 損失額入力
      m_risk.Create(m_chart_id, "edt_risk", m_subwin,
                    left+85, top-2, left+85+width-90, top+line_h+2);
      m_risk.Text("50000");
      m_risk.Color(clrLime);  // 緑色値
      m_risk.ColorBackground(clrBlack);
      m_risk.ColorBorder(clrGray);  // グレー枠

      top += line_h + margin;

      // TP利益額ラベル
      CLabel *lbl_tp = new CLabel;
      lbl_tp.Create(m_chart_id, "lbl_tp", m_subwin,
                    left, top, left+80, top+line_h);
      lbl_tp.Text("TP (JPY)");
      lbl_tp.Color(clrWhite);  // 白色ラベル
      lbl_tp.FontSize(9);

      // TP利益額入力（0で無効、1以上で有効）
      m_tp_profit.Create(m_chart_id, "edt_tp_profit", m_subwin,
                         left+85, top-2, left+85+width-90, top+line_h+2);
      m_tp_profit.Text("0");  // 0でTP無し
      m_tp_profit.Color(clrLime);  // 緑色値
      m_tp_profit.ColorBackground(clrBlack);
      m_tp_profit.ColorBorder(clrGray);  // グレー枠

      top += line_h + margin;

      // Buy / Sell ボタン
      int btn_w = (width - margin) / 2;

      m_buy.Create(m_chart_id, "btn_buy", m_subwin,
                   left, top, left+btn_w, top+line_h+5);
      m_buy.Text("BUY");
      m_buy.ColorBackground(clrLimeGreen);  // 明るい緑
      m_buy.Color(clrWhite);  // 白文字
      m_buy.FontSize(10);

      m_sell.Create(m_chart_id, "btn_sell", m_subwin,
                    left+btn_w+margin, top, left+btn_w+margin+btn_w, top+line_h+5);
      m_sell.Text("SELL");
      m_sell.ColorBackground(clrCrimson);  // 明るい赤
      m_sell.Color(clrWhite);  // 白文字
      m_sell.FontSize(10);

      top += line_h + margin + 5;

      // Close last / Close all ボタン
      m_closeLast.Create(m_chart_id, "btn_close_last", m_subwin,
                         left, top, left+btn_w, top+line_h+5);
      m_closeLast.Text("Close last");
      m_closeLast.ColorBackground(clrOrange);  // オレンジ
      m_closeLast.Color(clrWhite);
      m_closeLast.FontSize(9);

      m_closeAll.Create(m_chart_id, "btn_close_all", m_subwin,
                        left+btn_w+margin, top, left+btn_w+margin+btn_w, top+line_h+5);
      m_closeAll.Text("Close all");
      m_closeAll.ColorBackground(clrHotPink);  // ピンク
      m_closeAll.Color(clrWhite);
      m_closeAll.FontSize(9);

      top += line_h + margin + 5;

      // 現在時刻(JST)表示（ラベルと値を分離）
      m_lblTimeLabel.Create(m_chart_id, "lbl_time_label", m_subwin,
                            left, top, left+80, top+line_h);
      m_lblTimeLabel.Text("Time (JST):");
      m_lblTimeLabel.Color(clrWhite);  // 白色ラベル
      m_lblTimeLabel.FontSize(10);

      m_lblTimeValue.Create(m_chart_id, "lbl_time_value", m_subwin,
                            left+105, top, left+width, top+line_h);
      m_lblTimeValue.Text("-");
      m_lblTimeValue.Color(clrLime);  // 緑色値
      m_lblTimeValue.FontSize(11);

      top += line_h + margin;

      // 最後のポジション損益表示（ラベルと値を分離）
      m_lblPlLabel.Create(m_chart_id, "lbl_pl_label", m_subwin,
                          left, top, left+70, top+line_h);
      m_lblPlLabel.Text("Last P/L:");
      m_lblPlLabel.Color(clrWhite);  // 白色ラベル
      m_lblPlLabel.FontSize(9);

      m_lblPlValue.Create(m_chart_id, "lbl_pl_value", m_subwin,
                          left+75, top, left+width, top+line_h);
      m_lblPlValue.Text("-");
      m_lblPlValue.Color(clrLime);  // 緑色値
      m_lblPlValue.FontSize(11);

      top += line_h + margin;

      // メッセージ用ラベル
      m_msg.Create(m_chart_id, "lbl_msg", m_subwin,
                   left, top, left+width, top+line_h*2);
      m_msg.Text("Ready");
      m_msg.Color(clrLime);  // 緑色値
      m_msg.FontSize(7);

      // 初期表示更新
      UpdateTime();
      UpdateLastPositionPl();

      return(true);
   }

   // クリックイベント処理
   bool OnEvent(const int id,
                const long &lparam,
                const double &dparam,
                const string &sparam)
   {
      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         if(sparam == m_buy.Name())
         {
            PlaceOrder(true);
            return(true);
         }
         if(sparam == m_sell.Name())
         {
            PlaceOrder(false);
            return(true);
         }
         if(sparam == m_closeLast.Name())
         {
            CloseLastPosition();
            return(true);
         }
         if(sparam == m_closeAll.Name())
         {
            CloseAllPositions();
            return(true);
         }
      }
      return(false);
   }

   // SLラインを描画（点線）
   void DrawSlLine(const double sl_price)
   {
      const string obj_name = "RiskPanel_SL";

      ObjectDelete(m_chart_id, obj_name);

      if(ObjectCreate(m_chart_id, obj_name, OBJ_HLINE, 0, 0, sl_price))
      {
         ObjectSetDouble(m_chart_id,  obj_name, OBJPROP_PRICE, sl_price);
         ObjectSetInteger(m_chart_id, obj_name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(m_chart_id, obj_name, OBJPROP_WIDTH, 1);
      }
   }

   // SLライン削除
   void DeleteSlLine()
   {
      const string obj_name = "RiskPanel_SL";
      ObjectDelete(m_chart_id, obj_name);
   }

   // シンボル固有の最適なフィリングタイプを設定
   void SetOptimalFillingType(const string symbol)
   {
      long filling_mode = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
      
      Print("Symbol filling modes for ", symbol, ": ", filling_mode);
      
      // IOC（Immediate or Cancel）を優先的に試す
      if((filling_mode & 0x1) == 0x1)  // IOC
      {
         trade.SetTypeFilling(ORDER_FILLING_IOC);
         Print("Using ORDER_FILLING_IOC for ", symbol);
      }
      // FOK（Fill or Kill）を次に試す
      else if((filling_mode & 0x2) == 0x2)  // FOK
      {
         trade.SetTypeFilling(ORDER_FILLING_FOK);
         Print("Using ORDER_FILLING_FOK for ", symbol);
      }
      // どちらもサポートしていない場合はIOCをデフォルトで使用
      else
      {
         trade.SetTypeFilling(ORDER_FILLING_IOC);
         Print("Using default ORDER_FILLING_IOC for ", symbol);
      }
   }

   // 取引可能性をチェック
   bool IsSymbolTradable(const string symbol)
   {
      // シンボルが選択されているかチェック
      if(!SymbolSelect(symbol, true))
      {
         Print("Failed to select symbol: ", symbol);
         return false;
      }
      
      // 取引モードをチェック
      ENUM_SYMBOL_TRADE_MODE trade_mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
      Print("Trade mode for ", symbol, ": ", EnumToString(trade_mode));
      
      if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      {
         Print("Trading disabled for ", symbol);
         return false;
      }
      
      // 価格が取得できるかチェック
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      Print("Prices for ", symbol, " - Ask:", ask, " Bid:", bid);
      
      if(ask <= 0 || bid <= 0)
      {
         Print("Invalid prices for ", symbol, " Ask:", ask, " Bid:", bid);
         // 価格更新を試行
         MqlTick tick;
         if(!SymbolInfoTick(symbol, tick))
         {
            Print("Failed to update tick for ", symbol);
            return false;
         }
         
         // 再度価格を取得
         ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         Print("Updated prices for ", symbol, " - Ask:", ask, " Bid:", bid);
         
         if(ask <= 0 || bid <= 0)
         {
            return false;
         }
      }
      
      // 最小ロットサイズをチェック
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      Print("Lot sizes for ", symbol, " - Min:", min_lot, " Max:", max_lot);
      
      Print("Symbol ", symbol, " is tradable - Ask:", ask, " Bid:", bid);
      return true;
   }

   // 取引エラーの説明を取得
   string GetTradeErrorDescription(uint retcode)
   {
      switch(retcode)
      {
         case TRADE_RETCODE_REQUOTE:
            return "Requote";
         case TRADE_RETCODE_REJECT:
            return "Request rejected";
         case TRADE_RETCODE_CANCEL:
            return "Request canceled by trader";
         case TRADE_RETCODE_PLACED:
            return "Order placed";
         case TRADE_RETCODE_DONE:
            return "Request completed";
         case TRADE_RETCODE_DONE_PARTIAL:
            return "Only part of the request was completed";
         case TRADE_RETCODE_ERROR:
            return "Request processing error";
         case TRADE_RETCODE_TIMEOUT:
            return "Request canceled by timeout";
         case TRADE_RETCODE_INVALID:
            return "Invalid request";
         case TRADE_RETCODE_INVALID_VOLUME:
            return "Invalid volume in the request";
         case TRADE_RETCODE_INVALID_PRICE:
            return "Invalid price in the request";
         case TRADE_RETCODE_INVALID_STOPS:
            return "Invalid stops in the request";
         case TRADE_RETCODE_TRADE_DISABLED:
            return "Trade disabled (Check symbol settings and filling type)";
         case TRADE_RETCODE_MARKET_CLOSED:
            return "Market is closed";
         case TRADE_RETCODE_NO_MONEY:
            return "There is not enough money to complete the request";
         case TRADE_RETCODE_PRICE_CHANGED:
            return "Prices changed";
         case TRADE_RETCODE_PRICE_OFF:
            return "There are no quotes to process the request";
         case TRADE_RETCODE_INVALID_EXPIRATION:
            return "Invalid order expiration date in the request";
         case TRADE_RETCODE_ORDER_CHANGED:
            return "Order state changed";
         case TRADE_RETCODE_TOO_MANY_REQUESTS:
            return "Too frequent requests";
         case TRADE_RETCODE_NO_CHANGES:
            return "No changes in request";
         case TRADE_RETCODE_SERVER_DISABLES_AT:
            return "Autotrading disabled by server";
         case TRADE_RETCODE_CLIENT_DISABLES_AT:
            return "Autotrading disabled by client terminal";
         case TRADE_RETCODE_LOCKED:
            return "Request locked for processing";
         case TRADE_RETCODE_FROZEN:
            return "Order or position frozen";
         case TRADE_RETCODE_INVALID_FILL:
            return "Invalid order filling type (Try IOC or RETURN)";
         case TRADE_RETCODE_CONNECTION:
            return "No connection with the trade server";
         case TRADE_RETCODE_ONLY_REAL:
            return "Operation is allowed only for live accounts";
         case TRADE_RETCODE_LIMIT_ORDERS:
            return "The number of pending orders has reached the limit";
         case TRADE_RETCODE_LIMIT_VOLUME:
            return "The volume of orders and positions for the symbol has reached the limit";
         default:
            return StringFormat("Unknown error %d", retcode);
      }
   }

   // 注文実行（円指定リスクからSL自動計算）
   void PlaceOrder(bool is_buy)
   {
      string sym = _Symbol;  // チャートのシンボル

      // 取引可能性をチェック
      if(!IsSymbolTradable(sym))
      {
         m_msg.Text("Trading not available for " + sym);
         return;
      }

      string vol_str       = m_volume.Text();
      string risk_str      = m_risk.Text();
      string tp_profit_str = m_tp_profit.Text();

      double volume     = StringToDouble(vol_str);
      double risk_jpy   = StringToDouble(risk_str);
      double tp_profit  = StringToDouble(tp_profit_str);

      if(volume <= 0.0 || risk_jpy <= 0.0)
      {
         m_msg.Text("Volume/Risk invalid");
         return;
      }

      // 成行価格
      double price = is_buy
                     ? SymbolInfoDouble(sym, SYMBOL_ASK)
                     : SymbolInfoDouble(sym, SYMBOL_BID);
      if(price <= 0.0)
      {
         m_msg.Text("Price error");
         return;
      }

      // 契約サイズ
      double contract_size = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);
      if(contract_size <= 0.0)
      {
         m_msg.Text("Contract size error");
         return;
      }

      // ティック価値とサイズを取得
      double tick_value = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      
      // 口座通貨の確認
      string account_currency = AccountInfoString(ACCOUNT_CURRENCY);
      
      Print("Symbol info - Contract size: ", contract_size, ", Tick value: ", tick_value, ", Tick size: ", tick_size);
      Print("Account currency: ", account_currency);
      
      if(tick_value <= 0.0 || tick_size <= 0.0)
      {
         m_msg.Text("Tick info error");
         return;
      }

      // JPY口座でない場合は USD/JPY レートを使用して換算
      double conversion_rate = 1.0;
      if(account_currency != "JPY")
      {
         conversion_rate = SymbolInfoDouble(m_usdJpySymbol, SYMBOL_BID);
         if(conversion_rate <= 0.0)
         {
            m_msg.Text("USDJPY rate error");
            return;
         }
         Print("USD/JPY conversion rate: ", conversion_rate);
      }

      // 1単位価格変動時の損益（JPY換算）
      double value_per_unit_move = (tick_value / tick_size) * volume * conversion_rate;
      if(value_per_unit_move <= 0.0)
      {
         m_msg.Text("Calc error");
         return;
      }

      // 許容価格幅
      double D = risk_jpy / value_per_unit_move;
      
      Print("Risk calculation - Risk(JPY): ", risk_jpy, ", Value per unit(JPY): ", value_per_unit_move, ", Price range: ", D);

      // SL価格
      double sl_price = is_buy ? (price - D) : (price + D);

      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      sl_price = NormalizeDouble(sl_price, digits);

      // TP価格計算（0以下なら無効）
      double tp_price = 0.0;
      if(tp_profit > 0.0)
      {
         double tp_distance = tp_profit / value_per_unit_move;  // 利益額(円) ÷ 1単位価格変動時の損益
         tp_price = is_buy ? (price + tp_distance) : (price - tp_distance);
         tp_price = NormalizeDouble(tp_price, digits);
         Print("TP calculation - TP profit(JPY): ", tp_profit, ", TP distance: ", tp_distance, ", TP price: ", tp_price);
      }

      // 発注 - シンボルに応じたフィリングタイプを動的に設定
      SetOptimalFillingType(sym);

      bool result = false;
      if(is_buy)
         result = trade.Buy(volume, sym, price, sl_price, tp_price, "RiskPanel BUY");
      else
         result = trade.Sell(volume, sym, price, sl_price, tp_price, "RiskPanel SELL");

      if(result)
      {
         string side = is_buy ? "BUY" : "SELL";
         if(tp_price > 0.0)
            m_msg.Text(StringFormat("%s %s vol=%.2f SL=%.2f TP=%.2f",
                                    side, sym, volume, sl_price, tp_price));
         else
            m_msg.Text(StringFormat("%s %s vol=%.2f SL=%.2f",
                                    side, sym, volume, sl_price));

         DrawSlLine(sl_price);
      }
      else
      {
         uint retcode = trade.ResultRetcode();
         string error_message = GetTradeErrorDescription(retcode);
         m_msg.Text(StringFormat("Order failed: %s", error_message));
         Print(StringFormat("OrderSend error - Symbol: %s, Error: %d, Retcode: %d, Description: %s", 
                            sym, GetLastError(), retcode, error_message));
      }
   }

   // 最後のポジションを（このシンボルだけ）決済
   void CloseLastPosition()
   {
      string sym = _Symbol;
      int total = PositionsTotal();
      if(total <= 0)
      {
         m_msg.Text("No position");
         return;
      }

      ulong    last_ticket = 0;
      datetime last_time   = 0;

      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;

         string psym = PositionGetString(POSITION_SYMBOL);
         if(psym != sym)
            continue;

         datetime t = (datetime)PositionGetInteger(POSITION_TIME);
         if(t > last_time)
         {
            last_time   = t;
            last_ticket = ticket;
         }
      }

      if(last_ticket == 0)
      {
         m_msg.Text("No position for symbol");
         return;
      }

      if(trade.PositionClose(last_ticket))
      {
         m_msg.Text(StringFormat("Closed last ticket %I64u", last_ticket));
         // 残ポジがなければSLライン削除
         if(!HasAnyPositionForSymbol(sym))
            DeleteSlLine();
      }
      else
      {
         m_msg.Text(StringFormat("Close error: %d", GetLastError()));
      }
   }

   // このシンボルの全ポジションを決済
   void CloseAllPositions()
   {
      string sym = _Symbol;
      int total = PositionsTotal();
      if(total <= 0)
      {
         m_msg.Text("No position");
         return;
      }

      int closed = 0;

      // 後ろから回してもいいが、チケット単位で全部試す
      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;

         string psym = PositionGetString(POSITION_SYMBOL);
         if(psym != sym)
            continue;

         if(trade.PositionClose(ticket))
            closed++;
      }

      if(closed > 0)
      {
         m_msg.Text(StringFormat("Closed %d positions for %s", closed, sym));
         DeleteSlLine();
      }
      else
      {
         m_msg.Text("No position closed");
      }
   }

   // このシンボルにポジションが残っているか
   bool HasAnyPositionForSymbol(const string sym)
   {
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         string psym = PositionGetString(POSITION_SYMBOL);
         if(psym == sym)
            return(true);
      }
      return(false);
   }

   // 最後のポジションの現在損益を更新
   void UpdateLastPositionPl()
   {
      string sym = _Symbol;
      int total = PositionsTotal();

      double   pl        = 0.0;
      datetime last_time = 0;
      bool     found     = false;

      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;

         string psym = PositionGetString(POSITION_SYMBOL);
         if(psym != sym)
            continue;

         datetime t = (datetime)PositionGetInteger(POSITION_TIME);
         if(t > last_time)
         {
            last_time = t;
            pl        = PositionGetDouble(POSITION_PROFIT); // 口座通貨(JPY)前提
            found     = true;
         }
      }

      if(found)
      {
         m_lblPlValue.Text(StringFormat("%.0f JPY", pl));
         
         // 損益に応じて色を変更
         if(pl <= 0.0)
            m_lblPlValue.Color(clrRed);      // 0以下は赤字
         else
            m_lblPlValue.Color(clrBlue);     // 1以上は青字
      }
      else
      {
         m_lblPlValue.Text("-");
         m_lblPlValue.Color(clrLime);        // デフォルトは緑
      }
   }

   // 現在時刻(JST)表示更新（PCローカル時間をJSTとして使用）
   void UpdateTime()
   {
      datetime now = TimeLocal();  // PCローカル
      MqlDateTime mt;
      TimeToStruct(now, mt);

      string s = StringFormat("%04d-%02d-%02d %02d:%02d:%02d",
                              mt.year, mt.mon, mt.day,
                              mt.hour, mt.min, mt.sec);

      m_lblTimeValue.Text(s);
   }

   // シンボルの更新
   void UpdateSymbol()
   {
      string newSymbol = _Symbol;
      if(m_currentSymbol != newSymbol)
      {
         m_currentSymbol = newSymbol;
         m_lblSymbol.Text(StringFormat("Symbol: %s", newSymbol));
      }
   }

   // 定期更新（タイマーやティックで呼ぶ）
   void UpdateStatus()
   {
      UpdateSymbol();
      UpdateTime();
      UpdateLastPositionPl();
   }
};

//---------------------------------------------------------
// グローバル
//---------------------------------------------------------
input string InpUsdJpySymbol = "USDJPY"; // ブローカーのドル円シンボル名

CRiskPanel *g_panel = NULL;

//---------------------------------------------------------
// EAイベント
//---------------------------------------------------------
int OnInit()
{
   int x1 = 10;
   int y1 = 20;
   int x2 = 260;
   int y2 = 260;

   g_panel = new CRiskPanel(InpUsdJpySymbol);
   if(!g_panel.Create(ChartID(), "RiskPanelChartJP", 0, x1, y1, x2, y2))
      return(INIT_FAILED);

   // 1秒ごとに時計＆損益を更新
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();

   if(g_panel != NULL)
   {
      delete g_panel;
      g_panel = NULL;
   }
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(g_panel != NULL)
      g_panel.OnEvent(id, lparam, dparam, sparam);
}

// タイマーで1秒ごとに更新
void OnTimer()
{
   if(g_panel != NULL)
      g_panel.UpdateStatus();
}

// ティックごとに損益を更新
void OnTick()
{
   if(g_panel != NULL)
      g_panel.UpdateLastPositionPl();
}
