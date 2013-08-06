-- -*- coding: iso-8859-1-unix -*-

local msg = require "openbus.util.messages"

msg.ServiceVersion = "1.0.0.0"

-- openbus.core.bin.openbus
msg.CopyrightNotice = "OpenBus Collaboration Service "..
   msg.ServiceVersion.."  Copyright (C) 2013 Tecgraf, PUC-Rio"

msg.ServiceSuccessfullyStarted = "Servico de colaboracao "..
   msg.ServiceVersion.." iniciado com sucesso"

msg.CommandLineOptions = [[ [options]
Options:

  -host <address>            endereço de rede usado pelo serviço de colaboração
  -port <number>             número da porta usada pelo serviço de colaboração

  -bushost <address>         endereço de rede de acesso ao barramento
  -busport <number>          número da porta de acesso ao barramento

  -database <path>           arquivo de dados do serviço de colaboração
  -privatekey <path>         arquivo com chave privada do serviço de colaboração

  -loglevel <number>         nível de log gerado pelo serviço de colaboração
  -logfile <path>            arquivo de log gerado pelo serviço de colaboração
  -oilloglevel <number>      nível de log gerado pelo OiL (debug)
  -oillogfile <path>         arquivo de log gerado pelo OiL (debug)

  -configs <path>            arquivo de configurações do serviço de colaboração
]]

msg.createCollaborationSession = "criacao da sessao {$sessionId} pelo login "
  .."{$creator}"
msg.recoverySession = "recuperacao da sessao {$sessionId} criada pelo login "
  .."{$creator}"
msg.recoveryMember = "recuperacao do membro {$name} registrado na sessao "
  .."{$sessionId} pelo login {$owner}"
msg.recoveryMemberIOR = "membro {$name} com IOR=$ior"
msg.recoveryConsumer = "recuperacao do consumidor {cookie=$cookie, ior=$ior} "..
  "registrado na sessao {$sessionId}"
msg.recoveryObserver = "recuperacao do observador {cookie=$cookie, ior=$ior} "..
  "registrado na sessao {$sessionId}"

msg.delMember = "remocao do membro {$name} registrado na sessao {$sessionId}"
msg.addMember = "registro do membro {$name} na sessao {$sessionId} pelo login "
  .."{$owner}"
msg.getMember = "retorno do membro {$name} registrado na sessao {$sessionId}"
msg.addSession = "registro da sessao {$objkey} criada pelo login {$creator}"
msg.delSession = "destruicao da sessao {$sessionId}"

msg.subscribeObserver = "registro do observador {$ior} da sessao {$sessionId}"
msg.unsubscribeObserver = "remocao do observador {cookie=$cookie} da sessao "
 .."{$sessionId}"
msg.subscribeConsumer = "registro do consumidor {$ior} na sessao {$sessionId}"
msg.unsubscribeConsumer = "remocao do consumidor {cookie=$cookie} da sessao "
 .."{$sessionId}"

msg.openDB = "sqlite.open($filename): errCode=$errCode"
msg.prepareDB = "sqlite_conn.prepare($sql): errCode=$errCode"
msg.finalizeDB = "sqlite_stmt.finalize($stmt): errCode=$errCode"

return msg
