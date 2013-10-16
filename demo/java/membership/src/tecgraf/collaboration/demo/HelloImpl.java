package tecgraf.collaboration.demo;

import tecgraf.openbus.CallerChain;
import tecgraf.openbus.Connection;
import tecgraf.openbus.OpenBusContext;
import tecgraf.openbus.core.v2_0.services.access_control.LoginInfo;
import demo.Hello;
import demo.HelloPOA;

/**
 * Implementação do serviço {@link Hello} que será incluído na sessão de
 * colaboração.
 * 
 * @author Tecgraf
 */
public class HelloImpl extends HelloPOA {
  /**
   * Contexto com o barramento.
   */
  private OpenBusContext context;

  /**
   * Construtor.
   * 
   * @param context Conexão com o barramento.
   */
  public HelloImpl(OpenBusContext context) {
    this.context = context;
  }

  /**
   * {@inheritDoc}
   */
  @Override
  public void sayHello() {
    CallerChain callerChain = context.getCallerChain();
    LoginInfo caller = callerChain.caller();
    Connection conn = context.getCurrentConnection();
    String hello =
      String.format("Hello, %s! This is %s.", caller.entity,
        conn.login().entity);
    System.out.println(hello);
  }
}
