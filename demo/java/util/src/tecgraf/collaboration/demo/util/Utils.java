package tecgraf.collaboration.demo.util;

import java.util.logging.ConsoleHandler;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Classe utilitária para os demos Java.
 * 
 * @author Tecgraf
 */
public class Utils {

  /**
   * Texto explicativo de uso do demo.
   */
  public static final String usage =
    "Usage: 'demo' <host> <port> <entity> [password] %s\n"
      + "  - host = é o host do barramento\n"
      + "  - port = é a porta do barramento\n"
      + "  - entity = é a entidade a ser autenticada\n"
      + "  - password = senha (opcional) %s";

  /**
   * Erro a ser apresentado quando ocorrer mau uso do parâmetro "port"
   */
  public static final String port = "Valor de <port> deve ser um número";

  /**
   * Método auxiliar para extrair os parâmetros de entrada do demo.
   * 
   * @param args argumentos passados por linha de comando.
   * @return os parâmetros a serem utilizados no demo.
   */
  static public DemoParams retrieveParams(String[] args) {
    DemoParams params = new DemoParams();
    // verificando parametros de entrada
    if (args.length < 3) {
      System.out.println(String.format(Utils.usage, "", ""));
      System.exit(1);
      return null;
    }
    // - host
    params.host = args[0];
    // - porta
    try {
      params.port = Integer.parseInt(args[1]);
    }
    catch (NumberFormatException e) {
      System.out.println(Utils.port);
      System.exit(1);
      return null;
    }
    // - entidade
    params.entity = args[2];
    // - senha (opcional)
    if (args.length > 3) {
      params.password = args[3];
    }
    else {
      params.password = params.entity;
    }
    return params;
  }

  /**
   * Método utilitário para configurar o nível de log da API do OpenBus
   * 
   * @param level o nível de log.
   */
  public static void setLogLevel(Level level) {
    Logger logger = Logger.getLogger("tecgraf.openbus");
    logger.setLevel(level);
    logger.setUseParentHandlers(false);
    ConsoleHandler handler = new ConsoleHandler();
    handler.setLevel(level);
    logger.addHandler(handler);
  }

  /**
   * Método utilitário para configurar o nível de log do JacORB
   * 
   * @param level o nível de log.
   */
  public static void setJacorbLogLevel(Level level) {
    Logger logger = Logger.getLogger("jacorb");
    logger.setLevel(level);
    logger.setUseParentHandlers(false);
    ConsoleHandler handler = new ConsoleHandler();
    handler.setLevel(level);
    logger.addHandler(handler);
  }

  /**
   * Classe utilitária para estruturar os parâmetros de entrada do demo.
   * 
   * @author Tecgraf
   */
  public static class DemoParams {
    /** host */
    public String host = "localhost";
    /** porta */
    public int port = 2089;
    /** entidade */
    public String entity = "entity";
    /** senha */
    public String password = this.entity;
  }

}
