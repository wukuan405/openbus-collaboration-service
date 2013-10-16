package tecgraf.collaboration.demo;

import org.omg.CORBA.Any;
import org.omg.CORBA.TCKind;

import tecgraf.openbus.CallerChain;
import tecgraf.openbus.OpenBusContext;
import tecgraf.openbus.core.v2_0.services.ServiceFailure;
import tecgraf.openbus.core.v2_0.services.access_control.LoginInfo;
import tecgraf.openbus.services.collaboration.v1_0.EventConsumerPOA;

/**
 * Implementa um consumidor de eventos de uma aplicação. Esse consumidor de
 * eventos é registrado em um canal de eventos de uma sessão de colaboração.
 * 
 * @author Tecgraf PUC-Rio
 */
public class EventConsumerImpl extends EventConsumerPOA {

  /** contexto */
  private OpenBusContext context;

  /**
   * Construtor.
   * 
   * @param context
   */
  public EventConsumerImpl(OpenBusContext context) {
    this.context = context;
  }

  /**
   * {@inheritDoc}
   */
  @Override
  public void push(final Any event) throws ServiceFailure {
    CallerChain callerChain = context.getCallerChain();
    LoginInfo caller = callerChain.caller();
    if (callerChain.originators().length > 0) {
      caller = callerChain.originators()[0];
    }
    if (event.type().kind() == TCKind.tk_string) {
      String ev = event.extract_string();
      System.out.println(String.format("Received event from %s: %s",
        caller.entity, ev));
    }
    else {
      System.err.println(String.format(
        "Received an unexcepted event type from %s", caller.entity));
    }
  }
}
