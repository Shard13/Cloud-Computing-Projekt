import os, random, streamlit as st
NAME = "Guess Number"; VERSION = "v1"
st.set_page_config(page_title=f"{NAME} {VERSION}")
st.title(f"🎯 {NAME} — {VERSION}")
st.caption("Rate eine Zahl zwischen 1 und 20.")

if "secret" not in st.session_state:
    st.session_state.secret = random.randint(1, 20)

g = st.number_input("Dein Tipp:", min_value=1, max_value=20, step=1)
if st.button("Prüfen"):
    if g == st.session_state.secret:
        st.success("Richtig! Neue Zahl wurde gewählt.")
        st.session_state.secret = random.randint(1, 20)
    elif g < st.session_state.secret:
        st.info("Zu klein!")
    else:
        st.info("Zu groß!")
