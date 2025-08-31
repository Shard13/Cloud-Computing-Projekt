import os, random, streamlit as st
NAME = "Guess Number"; VERSION = "v2"
st.set_page_config(page_title=f"{NAME} {VERSION}")
st.title(f"🎯 {NAME} — {VERSION}")
mode = st.radio("Schwierigkeit", ["Leicht (1–20)", "Mittel (1–50)", "Schwer (1–100)"])
limit = 20 if "Leicht" in mode else 50 if "Mittel" in mode else 100

if "secret" not in st.session_state:
    st.session_state.secret = random.randint(1, limit)
    st.session_state.tries = 0

g = st.number_input(f"Dein Tipp (1–{limit}):", min_value=1, max_value=limit, step=1)
col1, col2 = st.columns(2)
if col1.button("Prüfen"):
    st.session_state.tries += 1
    if g == st.session_state.secret:
        st.success(f"Richtig in {st.session_state.tries} Versuchen! Neue Zahl gewählt.")
        st.session_state.secret = random.randint(1, limit)
        st.session_state.tries = 0
    elif g < st.session_state.secret:
        st.info("Zu klein!")
    else:
        st.info("Zu groß!")
if col2.button("Neu starten"):
    st.session_state.secret = random.randint(1, limit)
    st.session_state.tries = 0
st.caption(f"Versuche: {st.session_state.tries}")
