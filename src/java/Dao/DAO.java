package Dao;

import Model.Persona;
import Services.Configuration;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpDelete;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;

public class DAO {

    public List<Persona> listarPersonas() throws IOException {
        HttpClient httpClient = new DefaultHttpClient();
        JsonParser convert = new JsonParser();
        List<Persona> lista = new ArrayList();
        try {
            HttpGet request = new HttpGet(Configuration.Location + "/persongroups/usuarios/persons");
            request.addHeader("Ocp-Apim-Subscription-Key", Configuration.key);

            HttpResponse response = httpClient.execute(request);
            HttpEntity entity = response.getEntity();

            String cuerpo = EntityUtils.toString(entity);

            JsonArray body = convert.parse(cuerpo).getAsJsonArray();

            Persona person;

            for (JsonElement persons : body) {
                JsonObject element = persons.getAsJsonObject();
                person = new Persona(
                        element.get("personId").getAsString(),
                        element.get("name").getAsString(),
                        element.get("userData").getAsString(),
                        String.valueOf(element.get("persistedFaceIds").getAsJsonArray().size())
                );
                lista.add(person);
            }
            return lista;
        } catch (IOException e) {
            throw e;
        }
    }

    public void createPersonas(String name, String Descripcion) throws IOException {
        HttpClient httpClient = new DefaultHttpClient();
        try {
            StringEntity bodyInitial = new StringEntity("{\n"
                    + "    \"name\": \"" + name + "\",\n"
                    + "    \"userData\": \"" + Descripcion + "\"\n"
                    + "}");

            HttpPost request = new HttpPost(Configuration.Location + "/persongroups/usuarios/persons");
            request.addHeader("Content-Type", "application/json");
            request.addHeader("Ocp-Apim-Subscription-Key", Configuration.key);
            request.setEntity(bodyInitial);

            httpClient.execute(request);
        } catch (IOException e) {
            throw e;
        }
    }

    public void deletePersonas(String idPersona) throws IOException {
        HttpClient httpClient = new DefaultHttpClient();
        try {

            HttpDelete request = new HttpDelete(Configuration.Location + "/persongroups/usuarios/persons/" + idPersona);
            request.addHeader("Ocp-Apim-Subscription-Key", Configuration.key);

            httpClient.execute(request);
        } catch (IOException e) {
            throw e;
        }
    }

    public static void main(String[] args) throws IOException {
        DAO dao = new DAO();
        dao.createPersonas("Demo1", "Demo1");
    }

}
