package tecgraf.collaboration.demo.util;

import org.omg.CORBA.NO_PERMISSION;

import tecgraf.collaboration.demo.util.Utils.DemoParams;
import tecgraf.exception.handling.ExceptionContext;
import tecgraf.exception.handling.ExceptionHandler;
import tecgraf.exception.handling.ExceptionType;
import tecgraf.openbus.core.v2_0.services.ServiceFailure;
import tecgraf.openbus.core.v2_0.services.access_control.InvalidRemoteCode;
import tecgraf.openbus.core.v2_0.services.access_control.NoLoginCode;
import tecgraf.openbus.core.v2_0.services.access_control.UnknownBusCode;
import tecgraf.openbus.core.v2_0.services.access_control.UnverifiedLoginCode;

/**
 * Tratador de exceções padrão para os demos.
 * 
 * @author Tecgraf
 */
public class DemoExceptionHandler extends
  ExceptionHandler<DemoHandlingException> {

  /** Informações de configuração do demos */
  DemoParams params;

  /**
   * Construtor.
   * 
   * @param params
   */
  public DemoExceptionHandler(DemoParams params) {
    this.params = params;
  }

  /**
   * {@inheritDoc}
   */
  @Override
  protected void handleException(DemoHandlingException exception) {
    Exception theException = exception.getException();
    ExceptionType type = exception.getType();
    ExceptionContext context = exception.getContext();
    switch (type) {
      case AccessDenied:
        switch (context) {
          case LoginByPassword:
            System.err.println(String.format(
              "a senha fornecida para a entidade '%s' foi negada",
              params.entity));
            break;

          case LoginByCertificate:
            System.err.println(String.format(
              "a chave não corresponde ao certificado da entidade '%s'",
              params.entity));
            break;

          default:
            System.err.println("autenticação junto ao barramento falhou.");
            break;
        }
        break;

      case ServiceFailure:
        switch (context) {
          case BusCore:
            System.err.println(String.format(
              "falha severa no barramento em %s:%s : %s", params.host,
              params.port, ((ServiceFailure) theException).message));
            break;

          default:
            System.err.println(String.format("falha severa no serviço: %s",
              ((ServiceFailure) theException).message));
            break;
        }
        break;

      case OBJECT_NOT_EXIST:
        switch (context) {
          case BusCore:
            System.err.println(String.format(
              "referência para o barramento em %s:%s não existe.", params.host,
              params.port));
            break;

          default:
            System.err.println("referência para o serviço não existe");
            break;
        }
        break;

      case TRANSIENT:
        switch (context) {
          case BusCore:
            System.err.println(String.format(
              "o barramento em %s:%s esta inacessível no momento", params.host,
              params.port));
            break;

          default:
            System.err.println("serviço está indisponível no momento.");
            break;
        }
        break;

      case COMM_FAILURE:
        switch (context) {
          case BusCore:
            System.err
              .println("falha de comunicação ao acessar serviços núcleo do barramento");
            break;

          default:
            System.err.println("falha de comunicação ao acessar serviço.");
        }
        break;

      case NO_PERMISSION:
        NO_PERMISSION noPermission = (NO_PERMISSION) theException;
        switch (context) {
          case Service:
            switch (noPermission.minor) {
              case NoLoginCode.value:
                System.err.println(String.format(
                  "não há um login de '%s' válido no momento", params.entity));
                break;

              case UnknownBusCode.value:
                System.err
                  .println("o serviço encontrado não está mais logado ao barramento");
                break;

              case UnverifiedLoginCode.value:
                System.err
                  .println("o serviço encontrado não foi capaz de validar a chamada");
                break;

              case InvalidRemoteCode.value:
                System.err
                  .println("integração do serviço encontrado com o barramento está incorreta");
                break;
            }
            break;

          default:
            if (noPermission.minor == NoLoginCode.value) {
              System.err.println(String.format(
                "não há um login de '%s' válido no momento", params.entity));
            }
            else {
              System.err.println("Erro NO_PERMISSION inesperado.");
            }
            break;
        }
        break;

      case InvalidName:
        // Este erro nunca deveria ocorrer se o código foi bem escrito
        System.err.println(String.format("CORBA.InvalidName: %s", theException
          .getMessage()));
        System.exit(1);
        break;

      case Unspecified:
      default:
        System.err.println(String.format("Erro não categorizado: %s",
          theException.getMessage()));
        break;
    }
    // por fim imprime a pilha de erro para todas as exceções
    theException.printStackTrace();
  }

  /**
   * {@inheritDoc}
   */
  @Override
  protected DemoHandlingException getHandlingException(Exception exception,
    ExceptionContext context) {
    return new DemoHandlingException(exception, context);
  }

}
