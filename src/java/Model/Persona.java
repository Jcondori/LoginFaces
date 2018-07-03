package Model;

import lombok.Data;

@Data
public class Persona {

    private String Id;
    private String Nombre;
    private String Descripcion;
    private String Rostros;
    private String Confianza;

    public Persona() {
    }

    public Persona(String Id, String Nombre, String Descripcion, String Rostros) {
        this.Id = Id;
        this.Nombre = Nombre;
        this.Descripcion = Descripcion;
        this.Rostros = Rostros;
    }

    public Persona(String Id, String Confianza) {
        this.Id = Id;
        this.Confianza = Confianza;
    }

}
