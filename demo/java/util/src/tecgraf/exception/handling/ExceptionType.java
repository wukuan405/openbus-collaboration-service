package tecgraf.exception.handling;

/**
 * Esta enumeração deveria manter todas as exceções que se deseja tratar pelo
 * {@link ExceptionHandler}. Como não é possível estender um enum, deve-se
 * definir uma nova enumeração. O {@link ExceptionHandler} irá obter esta
 * enumeração através da definição de uma {@link HandlingException}.
 * 
 * @author Tecgraf
 */
public enum ExceptionType {
  // Contexto de Login (LoginBy* + BusCore)
  AccessDenied,
  AlreadyLoggedIn,
  // Contexto BusCore
  ServiceFailure,
  UnauthorizedFacets,
  InvalidService,
  // Exceções CORBA
  InvalidName,
  NO_PERMISSION,
  COMM_FAILURE,
  TRANSIENT,
  OBJECT_NOT_EXIST,
  // Outros
  /** Exceções não categorizadas */
  Unspecified;

  /**
   * Recupera um {@link ExceptionType} a partir da exceção real.
   * 
   * @param exception a exceção real
   * @return a enumeração que representa a exceção
   */
  public static ExceptionType getType(Exception exception) {
    try {
      Class<? extends Exception> theClass = exception.getClass();
      return ExceptionType.valueOf(theClass.getSimpleName());
    }
    catch (IllegalArgumentException ex) {
      return ExceptionType.Unspecified;
    }
  }

}
