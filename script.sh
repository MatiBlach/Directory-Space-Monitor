#!/bin/bash

# Nazwa skryptu: Monitorowanie zajętości katalogów użytkownika
# Autor: Mateusz Blach
# Data utworzenia: 27.05.2023
# Licencja: MIT License

# Opis: Skrypt kontroluje zajętość katalogów, maksymalną ilość plików w katalogach oraz zakazane formaty plików.


# Stałe wartości
log_file="log.txt"

# Funkcja tworząca nowy plik dziennika lub usuwająca istniejący plik
create_log_file() {
    if [ -f "$log_file" ]; then
        > "$log_file"
    else
        touch "$log_file"
    fi
}

# Wywołanie funkcji do tworzenia lub czyszczenia pliku dziennika
create_log_file

# Inicjalizacja zmiennych
max_size=0
max_files=0
forbidden_types=""
watch_directories=()

# Funkcja wyświetlająca menu
show_menu() {
    # Opcje menu
    selected_option=$(zenity --list --title "Menu" --column "Opcje" "1. Zaktualizuj maksymalny rozmiar" "2. Zaktualizuj maksymalną liczbę plików" "3. Zaktualizuj zakazane typy plików" "4. Zaktualizuj katalogi do monitorowania" "5. Sprawdź limity" "6. Wyjdź")

    case $selected_option in
        "1. Zaktualizuj maksymalny rozmiar")
            update_max_size
            ;;
        "2. Zaktualizuj maksymalną liczbę plików")
            update_max_files
            ;;
        "3. Zaktualizuj zakazane typy plików")
            update_forbidden_types
            ;;
        "4. Zaktualizuj katalogi do monitorowania")
            update_watch_directories
            ;;
        "5. Sprawdź limity")
            check_limits
            ;;
        "6. Wyjdź")
            exit 0
            ;;
    esac
}

# Funkcja aktualizująca maksymalny rozmiar
update_max_size() {
    while true; do
        new_max_size=$(zenity --entry --title "Maksymalny rozmiar" --text "Podaj maksymalny rozmiar (w megabajtach) dostępny dla katalogów użytkownika:" --entry-text "$((max_size / 1024))")

        # Walidacja wprowadzonej wartości
        if [[ ! $new_max_size =~ ^[0-9]+$ ]]; then
            zenity --error --title "Błąd" --text "Wprowadzono nieprawidłową wartość dla maksymalnego rozmiaru."
            log_message "Błąd: Nieprawidłowa wartość dla maksymalnego rozmiaru: $new_max_size"
        else
            max_size=$((new_max_size * 1024))
            log_message "Zaktualizowano maksymalny rozmiar: $new_max_size MB"
            break
        fi
    done

    show_menu
}

# Funkcja aktualizująca maksymalną liczbę plików
update_max_files() {
    while true; do
        new_max_files=$(zenity --entry --title "Maksymalna liczba plików" --text "Podaj maksymalną liczbę plików:" --entry-text "$max_files")

        # Walidacja wprowadzonej wartości
        if [[ ! $new_max_files =~ ^[0-9]+$ ]]; then
            zenity --error --title "Błąd" --text "Wprowadzono nieprawidłową wartość dla maksymalnej liczby plików."
            log_message "Błąd: Nieprawidłowa wartość dla maksymalnej liczby plików: $new_max_files"
        else
            max_files=$new_max_files
            log_message "Zaktualizowano maksymalną liczbę plików: $max_files"
            break
        fi
    done

    show_menu
}

# Funkcja aktualizująca zakazane typy plików
update_forbidden_types() {
    forbidden_types=$(zenity --entry --title "Zakazane typy plików" --text "Podaj zakazane typy plików (oddzielone przecinkami):" --entry-text "$forbidden_types")
    log_message "Zaktualizowano zakazane typy plików: $forbidden_types"
    show_menu
}

# Funkcja aktualizująca katalogi do monitorowania
update_watch_directories() {
    directories=$(zenity --file-selection --directory --multiple --title "Katalogi do monitorowania")
    IFS="|" read -ra watch_directories <<< "$directories"
    log_message "Zaktualizowano katalogi do monitorowania: ${watch_directories[*]}"
    show_menu
}

# Funkcja sprawdzająca zakazane formaty 
check_forbidden_files() {
    for directory in "${watch_directories[@]}"; do
        if [ -d "$directory" ]; then
            if [ -n "$forbidden_types" ]; then
                IFS=',' read -ra forbidden_extensions <<< "$forbidden_types"
                for extension in "${forbidden_extensions[@]}"; do
                    forbidden_files=$(find "$directory" -type f -name "*.$extension")
                    if [ -n "$forbidden_files" ]; then
                        for file in $forbidden_files; do
                            if zenity --question --title "Potwierdzenie usunięcia" --text "Czy na pewno chcesz usunąć plik $file?"; then
                                rm -f "$file"
                                log_message "Usunięto plik: $file"
                            fi
                        done
                    fi
                done
            fi
        fi
    done
}

# Funkcja sprawdzająca limit rozmiaru katalogów
check_size_limit() {
    for directory in "${watch_directories[@]}"; do
        while [ "$total_size" -gt "$max_size" ]; do
            oldest_file=$(find "$directory" -type f -printf '%T@ %p\n' | sort -n | head -n 1 | awk '{print $2}')

            if [ -n "$oldest_file" ]; then
                if zenity --question --title "Potwierdzenie usunięcia" --text "Czy na pewno chcesz usunąć plik $oldest_file?"; then
                    rm -f "$oldest_file"
                    total_size=$(du -s "$directory" | awk '{print $1}')
                    log_message "Usunięto plik: $oldest_file"
                else
                    break
                fi
            else
                break
            fi
        done
    done
}

# Funkcja sprawdzajaca limit liczby plików
check_file_limit() {
    for directory in "${watch_directories[@]}"; do
        while [ "$total_files" -gt "$max_files" ]; do
            oldest_file=$(find "$directory" -type f -printf '%T@ %p\n' | sort -n | head -n 1 | awk '{print $2}')

            if [ -n "$oldest_file" ]; then
                if zenity --question --title "Potwierdzenie usunięcia" --text "Czy na pewno chcesz usunąć plik $oldest_file?"; then
                    rm -f "$oldest_file"
                    total_files=$((total_files - 1))
                    log_message "Usunięto plik: $oldest_file"
                else
                    break
                fi
            else
                break
            fi
        done
    done
}

# Funkcja sprawdzająca limit
check_limits() {
    if [ "${#watch_directories[@]}" -eq 0 ]; then
        zenity --error --title "Błąd" --text "Nie wybrano żadnych katalogów."
        show_menu
        return
    fi

    total_size=0
    total_files=0
    files_to_delete=()
    forbidden_files_found=0

    for directory in "${watch_directories[@]}"; do
        if [ -d "$directory" ]; then
            dir_size=$(du -s "$directory" | awk '{print $1}')
            dir_files=$(find "$directory" -type f | wc -l)

            total_size=$((total_size + dir_size))
            total_files=$((total_files + dir_files))
        fi
    done

    check_forbidden_files
    check_size_limit
    check_file_limit
}

# Funkcja logująca komunikat
log_message() {
    timestamp=$(date +"%Y-%m-%d %T")
    echo "[$timestamp] $1" >> "$log_file"
}

# Obsługa opcji
if [[ $1 == "-v" ]]; then
    echo "Wersja skryptu: 1.0"
    echo "Autor: Mateusz Blach"
    exit 0
elif [[ $1 == "-h" ]]; then
    echo "Skrypt do monitorowania zajętości katalogów użytkownika."
    echo "Opcje:"
    echo "  -h: Wyświetla pomoc"
    echo "  -v: Wyświetla informacje o wersji i autorze"
    echo " "
    echo "Użytkownik za pomocą zenity ustawia parametry."
    echo "Po wciśnięciu opcji 'Sprawdź limity' skrypt"
    echo "zacznie działać w tle. Informacja o usuniętych"
    echo "plikach są zapisywane do pliku log.txt"
    exit 0
fi

# Wywołanie głównego menu
show_menu


# Działanie skryptu w tle 
while true; do
    check_limits
    
    sleep 10
done

