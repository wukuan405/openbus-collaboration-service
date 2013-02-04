-- -*- coding: iso-8859-1-unix -*-

local msg = require "openbus.util.messages"

msg.ServiceVersion = "2.0"

-- openbus.core.bin.openbus
msg.CopyrightNotice = "OpenBus Session Service "..msg.ServiceVersion.."  Copyright (C) 2012 Tecgraf, PUC-Rio"
msg.ServiceSuccessfullyStarted = "Serviço de colaboração "..msg.ServiceVersion.." iniciado com sucesso"

return msg
