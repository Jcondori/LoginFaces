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
import javax.faces.application.FacesMessage;
import javax.faces.context.FacesContext;
import lombok.Data;

@Data
@Named(value = "controller")
@SessionScoped
public class Controller implements Serializable {

    private List<Persona> LstPersonas = new ArrayList();
    private Persona persona = new Persona();
    private Faces faces = new Faces();

    private String urlImagen;
    private String urlIndetificado;
    private String respuestaConfianza;
    private Persona personaIdentificada = new Persona();

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

    public void trainGrupoPerson() throws IOException {
        DAO dao;
        try {
            dao = new DAO();
            dao.trainPersonas();
            FacesContext.getCurrentInstance().addMessage(null, new FacesMessage("Entrenado Correctamente"));
        } catch (IOException e) {
            throw e;
        }
    }

    public void identifyFaces() throws IOException {
        DAO dao;
        try {
            dao = new DAO();
            personaIdentificada = dao.faceIdentify(dao.faceDetect(urlImagen));
            if (personaIdentificada != null) {
                setRespuestaConfianza(personaIdentificada.getConfianza());
                personaIdentificada = dao.getPerson(personaIdentificada.getId());
                personaIdentificada.setConfianza(getRespuestaConfianza());
                setUrlIndetificado(getUrlImagen());
                FacesContext.getCurrentInstance().addMessage(null, new FacesMessage("Encontrado"));
            } else {
                setUrlIndetificado("https://ih0.redbubble.net/image.11241105.4427/ra,fitted_v_neck,x1950,45474B:e9c9d4e890,front-c,275,133,750,1000-bg,f8f8f8.lite-1.jpg");
                FacesContext.getCurrentInstance().addMessage(null, new FacesMessage("No se encontro"));
            }
            setUrlImagen(null);
            setRespuestaConfianza(null);
        } catch (IOException e) {
            throw e;
        }
    }

    public void clean() {
        persona = new Persona();
        faces = new Faces();
    }

}
