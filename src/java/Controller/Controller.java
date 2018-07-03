package Controller;

import Dao.DAO;
import Model.Faces;
import Model.Persona;
import java.io.IOException;
import javax.inject.Named;
import javax.enterprise.context.SessionScoped;
import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.annotation.PostConstruct;
import lombok.Data;

@Data
@Named(value = "controller")
@SessionScoped
public class Controller implements Serializable {

    private List<Persona> LstPersonas = new ArrayList();
    private Persona persona = new Persona();
    private Faces faces = new Faces();

    @PostConstruct
    public void start() {
        try {
            listarPersonas();
        } catch (IOException ex) {
            Logger.getLogger(Controller.class.getName()).log(Level.SEVERE, null, ex);
        }
    }

    public void listarPersonas() throws IOException {
        DAO dao;
        try {
            dao = new DAO();
            LstPersonas = dao.listarPersonas();
        } catch (IOException e) {
            throw e;
        }
    }

    public void createPerson() throws IOException {
        DAO dao;
        try {
            dao = new DAO();
            dao.createPersonas(persona.getNombre(), persona.getDescripcion());
            clean();
            listarPersonas();
        } catch (IOException e) {
            throw e;
        }
    }

    public void deletePerson() throws IOException {
        DAO dao;
        try {
            dao = new DAO();
            dao.deletePersonas(persona.getId());
            clean();
            listarPersonas();
        } catch (IOException e) {
            throw e;
        }
    }
    
    public void addFacesPerson() throws IOException {
        DAO dao;
        try {
            dao = new DAO();
            dao.addFacesPersonas(persona.getId(), faces.getUrl(), faces.getDescripcion());
            clean();
            listarPersonas();
        } catch (IOException e) {
            throw e;
        }
    }

    public void clean() {
        persona = new Persona();
        faces = new Faces();
    }
    
    
}
