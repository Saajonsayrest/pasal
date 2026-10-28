//! PASAL Mac app. The window shows the website build. The only native part is the Keychain:
//! the web code asks for the login token through these three commands (`src/lib/token-store.ts`).
//! The token is never written to a file or a log, and errors do not contain it.

use keyring::{Entry, Error};

const SERVICE: &str = "app.pasal.desktop";
const ACCOUNT: &str = "api-token";

fn entry() -> Result<Entry, String> {
    Entry::new(SERVICE, ACCOUNT).map_err(|e| e.to_string())
}

fn read(entry: &Entry) -> Result<Option<String>, String> {
    match entry.get_password() {
        Ok(token) => Ok(Some(token)),
        Err(Error::NoEntry) => Ok(None),
        Err(e) => Err(e.to_string()),
    }
}

fn write(entry: &Entry, token: &str) -> Result<(), String> {
    entry.set_password(token).map_err(|e| e.to_string())
}

fn remove(entry: &Entry) -> Result<(), String> {
    match entry.delete_credential() {
        Ok(()) | Err(Error::NoEntry) => Ok(()),
        Err(e) => Err(e.to_string()),
    }
}

#[tauri::command]
fn token_get() -> Result<Option<String>, String> {
    read(&entry()?)
}

#[tauri::command]
fn token_set(token: String) -> Result<(), String> {
    write(&entry()?, &token)
}

#[tauri::command]
fn token_clear() -> Result<(), String> {
    remove(&entry()?)
}

pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![token_get, token_set, token_clear])
        .run(tauri::generate_context!())
        .expect("PASAL could not start");
}

#[cfg(test)]
mod tests {
    use super::*;
    use keyring::{mock, set_default_credential_builder};

    #[test]
    fn token_round_trip() {
        set_default_credential_builder(mock::default_credential_builder());
        let entry = Entry::new("test", "token").unwrap();

        assert_eq!(read(&entry).unwrap(), None); // nothing saved yet is not an error
        write(&entry, "abc").unwrap();
        assert_eq!(read(&entry).unwrap(), Some("abc".to_string()));
        remove(&entry).unwrap();
        assert_eq!(read(&entry).unwrap(), None);
        remove(&entry).unwrap(); // clearing twice is fine
    }
}
