package tecgraf.exception.handling;

/**
 * Enumeração dos tipos de contextos
 * 
 * @author Tecgraf
 */
public enum ExceptionContext {
  /** Login por senha */
  LoginByPassword,
  /** Login por chave privada */
  LoginByCertificate,
  /** Chamadas ao núcleo do barramento */
  BusCore,
  /** Chamadas a serviços */
  Service,
  /** Chamadas locais */
  Local;
}