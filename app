import streamlit as st
import sqlite3
import pandas as pd

# Connexion à la base de données
conn = sqlite3.connect('hotel.db')

# Configuration de la page
st.set_page_config(page_title="Gestion Hôtelière", layout="wide")
st.title("🏨 Système de Gestion Hôtelière")

# Menu de navigation
menu = st.sidebar.selectbox(
    "Menu",
    ["Accueil", "Réservations", "Clients", "Chambres Disponibles", "Ajouter Client", "Ajouter Réservation"]
)

# Fonctions utilitaires
def get_reservations():
    return pd.read_sql("""
    SELECT r.id_reservation, r.nomcomplet, h.ville, r.datearrivee, r.datedepart
    FROM reservation r
    JOIN client c ON c.nomcomplet = r.nomcomplet
    JOIN concerner con ON con.id_reservation = r.id_reservation
    JOIN chambre ch ON con.id_type = ch.id_type
    JOIN Hotel h ON h.id_hotel = ch.id_hotel
    """, conn)

def get_clients():
    return pd.read_sql("SELECT * FROM client", conn)

def get_available_rooms(start_date, end_date):
    return pd.read_sql(f"""
    SELECT c.id_chambre, t.typee, t.tarif
    FROM chambre c
    JOIN typechambre t ON c.id_type = t.id_type
    WHERE c.id_chambre NOT IN (
        SELECT DISTINCT ch.id_chambre
        FROM concerner co
        JOIN chambre ch ON ch.id_type = co.id_type
        JOIN reservation r ON co.id_reservation = r.id_reservation
        WHERE r.datedepart >= '{start_date}' AND r.datearrivee <= '{end_date}'
    )
    """, conn)

# Pages de l'application
if menu == "Accueil":
    st.header("Bienvenue dans le système de gestion hôtelière")
    st.write("Utilisez le menu de gauche pour naviguer.")

elif menu == "Réservations":
    st.header("📋 Liste des Réservations")
    reservations = get_reservations()
    st.dataframe(reservations)

elif menu == "Clients":
    st.header("👥 Liste des Clients")
    clients = get_clients()
    st.dataframe(clients)

elif menu == "Chambres Disponibles":
    st.header("🛏️ Chambres Disponibles")
    col1, col2 = st.columns(2)
    with col1:
        start_date = st.date_input("Date d'arrivée")
    with col2:
        end_date = st.date_input("Date de départ")
    
    if st.button("Rechercher"):
        if start_date > end_date:
            st.error("La date de départ doit être après la date d'arrivée")
        else:
            rooms = get_available_rooms(start_date, end_date)
            if len(rooms) > 0:
                st.dataframe(rooms)
            else:
                st.warning("Aucune chambre disponible pour cette période")

elif menu == "Ajouter Client":
    st.header("➕ Ajouter un Nouveau Client")
    with st.form("client_form"):
        nomcomplet = st.text_input("Nom complet")
        adresse = st.text_input("Adresse")
        ville = st.text_input("Ville")
        codepostal = st.number_input("Code postal", min_value=0)
        email = st.text_input("Email")
        numtele = st.text_input("Numéro de téléphone")
        
        if st.form_submit_button("Enregistrer"):
            try:
                conn.execute("""
                INSERT INTO client VALUES (?, ?, ?, ?, ?, ?)
                """, (adresse, ville, codepostal, email, numtele, nomcomplet))
                conn.commit()
                st.success("Client ajouté avec succès!")
            except sqlite3.IntegrityError:
                st.error("Ce client existe déjà ou l'email est déjà utilisé")

elif menu == "Ajouter Réservation":
    st.header("📅 Ajouter une Nouvelle Réservation")
    clients = get_clients()
    client_list = clients['nomcomplet'].tolist()
    
    with st.form("reservation_form"):
        client = st.selectbox("Client", client_list)
        start_date = st.date_input("Date d'arrivée")
        end_date = st.date_input("Date de départ")
        
        if start_date <= end_date:
            available_rooms = get_available_rooms(start_date, end_date)
            room_list = [f"{row['id_chambre']} - {row['typee']} (${row['tarif']})" 
                        for _, row in available_rooms.iterrows()]
            room = st.selectbox("Chambre disponible", room_list)
        else:
            st.warning("La date de départ doit être après la date d'arrivée")
        
        if st.form_submit_button("Réserver"):
            room_id = int(room.split(" - ")[0])
            # Trouver le type de chambre
            room_type = conn.execute("""
            SELECT id_type FROM chambre WHERE id_chambre = ?
            """, (room_id,)).fetchone()[0]
            
            # Créer la réservation
            max_id = conn.execute("SELECT MAX(id_reservation) FROM reservation").fetchone()[0] or 0
            new_id = max_id + 1
            
            conn.execute("""
            INSERT INTO reservation VALUES (?, ?, ?, ?)
            """, (start_date, end_date, new_id, client))
            
            # Lier la réservation au type de chambre
            conn.execute("""
            INSERT INTO concerner VALUES (?, ?)
            """, (new_id, room_type))
            
            conn.commit()
            st.success("Réservation enregistrée avec succès!")

# Fermer la connexion
conn.close()
