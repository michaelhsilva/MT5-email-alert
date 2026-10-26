//+------------------------------------------------------------------+
//| AvisoSemOperacao.mq5                                             |
//| Envia e-mail quando a conta fica sem posições abertas:           |
//|  - após MinutesFlat minutos sem operação, ou                     |
//|  - imediatamente se o saldo mudar enquanto estiver sem operação  |
//+------------------------------------------------------------------+
#property strict

input int  CheckSeconds         = 30;   // intervalo de verificação (segundos)
input int  MinutesFlat          = 5;    // minutos sem operação antes de avisar
input bool AlertOnBalanceChange = true; // avisar na hora se o saldo mudar

bool     alertSent   = false;
datetime flatSince   = 0;
double   lastBalance = 0;

int OnInit()
{
   lastBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   EventSetTimer(CheckSeconds);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

bool EnviarAviso(string motivo)
{
   string msg = motivo + "\n" +
                "Conta: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n" +
                "Sem operações abertas desde: " + TimeToString(flatSince) + "\n" +
                "Saldo atual: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " " +
                AccountInfoString(ACCOUNT_CURRENCY);

   if(SendMail("MetaTrader: conta sem operação", msg))
      return true;

   Print("Falha ao enviar e-mail. Erro: ", GetLastError());
   return false;
}

void OnTimer()
{
   double balance        = AccountInfoDouble(ACCOUNT_BALANCE);
   bool   balanceChanged = MathAbs(balance - lastBalance) > 0.005;

   // Sem posições abertas e sem ordens pendentes
   if(PositionsTotal() == 0 && OrdersTotal() == 0)
   {
      if(flatSince == 0) flatSince = TimeCurrent();

      if(AlertOnBalanceChange && balanceChanged)
      {
         string motivo = "Saldo alterado: " + DoubleToString(lastBalance, 2) +
                         " -> " + DoubleToString(balance, 2);
         if(EnviarAviso(motivo))
         {
            alertSent   = true;      // evita repetir o aviso por tempo
            lastBalance = balance;
         }
         return;                     // se falhar, tenta de novo no próximo ciclo
      }

      if(!alertSent && TimeCurrent() - flatSince >= MinutesFlat * 60)
      {
         if(EnviarAviso("Conta sem operações há " + IntegerToString(MinutesFlat) + " minuto(s)."))
            alertSent = true;
      }
   }
   else
   {
      // Voltou a operar: reseta para avisar de novo na próxima vez
      flatSince = 0;
      alertSent = false;
   }

   lastBalance = balance;
}