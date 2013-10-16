package tecgraf.exception.handling;

/**
 * Classe utilitária para reusar os códigos de tratamento de exceções.
 * 
 * @author Tecgraf
 * @param <T> O tipo de exceção que será tratado por esta classe.
 */
public abstract class ExceptionHandler<T extends HandlingException<?>> {

  /**
   * Método a ser disparado pela aplicação para tratar a exceção ocorrida no
   * contexto indicado.
   * 
   * @param theException a exceção.
   * @param context o contexto de execução em que o erro ocorreu.
   * @return um enum do tipo da exceção para que a aplicação possa fazer uso de
   *         switch, facilitando o tratamento da exceção que é particular a cada
   *         contexto de execução (parte do tratamento da exceção que não é
   *         reutilizável para todos os contextos)
   */
  public T process(Exception theException, ExceptionContext context) {
    T exception = getHandlingException(theException, context);
    handleException(exception);
    return exception;
  }

  /**
   * A idéia deste método é chamr o construtor de {@link HandlingException}
   * específco, que por sua vez irá utilizar o método
   * {@link HandlingException#getTypeFromException(Exception)} para obter a
   * enumeração específica ({@link ExceptionType}).
   * 
   * @param realException a exceção ocorrida.
   * @param context o contexto da exceção.
   * @return a instância de {@link HandlingException} a ser tratada.
   */
  protected abstract T getHandlingException(Exception realException,
    ExceptionContext context);

  /**
   * Método a ser definido pela aplicação para de fato explicitar o tratamento
   * da exceção que deve ser reutilizado.
   * 
   * @param exception a exceção a ser tratada.
   */
  protected abstract void handleException(T exception);

}
