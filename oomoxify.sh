#!/bin/bash
set -ueo pipefail

root="$(readlink -e $(dirname "$0"))"
SRC_PATH=${root}


spotify_apps_path="/usr/share/spotify/Apps"
backup_dir="${HOME}/.config/oomox/spotify_backup"


print_usage() {
	echo "
usage:
$0 [-s /path/to/spotify/Apps] [-f] PRESET_NAME_OR_PATH

options:
	-s, --spotify-apps-path		path to spotify/Apps
	-f, --system-font			use system font
	-w, --font-weight			'normalize' font weight
	-g, --gui					use 'gksu' instead of sudo

examples:
	$0 monovedek
	$0 -f ./colors/gnome-colors/shiki-noble
	$0 -o /opt/spotify/Apps ./colors/retro/twg"
	exit 1
}


darker() {
	${root}/scripts/darker.sh $@
}
is_dark() {
	${root}/scripts/is_dark.sh $@
}


while [[ $# > 0 ]]
do
	case ${1} in
		-h|--help)
			print_usage
			exit 0
		;;
		-f|--system-font)
			use_system_font="True"
		;;
		-w|--font-weight)
			fix_font_weight="True"
		;;
		-g|--gui)
			gui="True"
		;;
		-s|--spotify-apps-path)
			spotify_apps_path="${2}"
			shift
		;;
		*)
			if [[ "${1}" == -* ]] || [[ ${THEME-} ]]; then
				echo "unknown option ${1}"
				print_usage
				exit 2
			fi
			THEME="${1}"
		;;
	esac
	shift
done

if [[ -z "${THEME:-}" ]] ; then
	print_usage
fi

if [[ ${THEME} == */* ]] || [[ ${THEME} == *.* ]] ; then
	source "$THEME"
	THEME=$(basename ${THEME})
else
	source "${root}/colors/$THEME"
fi

main_bg="${SPOTIFY_MAIN_BG-$MENU_BG}"
area_bg="${SPOTIFY_AREA_BG-$(darker ${MENU_BG})}"
selected_row_bg_fallback="$(darker ${MENU_BG} -10)"
selected_area_bg_fallback="$(darker ${MENU_BG} -18)"
selected_row_bg="${SPOTIFY_SELECTED_ROW_BG-$selected_row_bg_fallback}"
selected_area_bg="${SPOTIFY_SELECTED_AREA_BG-$selected_area_bg_fallback}"

set +e
is_dark ${MENU_FG}
fg_is_dark="$?"
set -e
if [[ ${fg_is_dark} -eq 0 ]] ; then
	main_fg_fallback="$(darker ${MENU_FG} -18)"
	accent_fg_fallback="$(darker ${MENU_FG} 36)"
else
	main_fg_fallback="$(darker ${MENU_FG} 18)"
	accent_fg_fallback="$(darker ${MENU_FG} -36)"
fi
sidebar_fg="${SPOTIFY_SIDEBAR_FG-$MENU_FG}"
main_fg="${SPOTIFY_MAIN_FG-$main_fg_fallback}"
accent_fg="${SPOTIFY_ACCENT_FG-$accent_fg_fallback}"

hover_text="${SPOTIFY_HOVER_TEXT-$SEL_BG}"
selected_text_color="${SPOTIFY_SELECTED_TEXT_COLOR-$SEL_BG}"
selected_button_color_fallback="${SEL_BG}"
hover_selection_color_fallback="$(darker ${SEL_BG} -25)"
selected_button_color="${SPOTIFY_SELECTED_BUTTON_COLOR-$selected_button_color_fallback}"
hover_selection_color="${SPOTIFY_HOVER_SELECTION_COLOR-$hover_selection_color_fallback}"


tmp_dir="$(mktemp -d)"
output_dir="$(mktemp -d)"
function post_clean_up {
	rm -r "${tmp_dir}" || true
	rm -r "${output_dir}" || true
}
trap post_clean_up EXIT SIGHUP SIGINT SIGTERM

backup_file="${backup_dir}/version.txt"
spotify_version=$(spotify --version 2>&1 | grep "^Spotify" | cut -d' ' -f3 | tr -d ',')
spotify_version_in_backup=$(cat "${backup_file}" || true)
if [[ $spotify_version != $spotify_version_in_backup ]] ; then
	if [[ -d "${backup_dir}" ]] ; then
		rm -r "${backup_dir}"
	fi
fi
if [[ ! -d "${backup_dir}" ]] ; then
	mkdir "${backup_dir}"
	cp -prf "${spotify_apps_path}"/*.spa "${backup_dir}/"
	echo "${spotify_version}" > "${backup_file}"
fi


cd "${root}"
for file in $(ls "${backup_dir}"/*.spa) ; do
	filename="$(basename "${file}")"
	echo "${filename}"
	cp "${file}" "${tmp_dir}/"
	cd "${tmp_dir}"
	unzip "./${filename}" > /dev/null
	if [[ -d ./css/ ]] && [[ -f ./css/style.css ]] ; then
		for css in $(ls ./css/*.css); do
			if [ ! -z "${use_system_font:-}" ] ; then
				replace_font=sans-serif
				sed -i \
					-e "s/'spotify-circular'/${replace_font}/g" \
					-e "s/'circular_sp_.*'/${replace_font}/g" \
					-e "s/font-family: circular_.*/font-fmaily: ${replace_font}/g" \
					-e "s/Monaco/monospace/g" \
					-e "s/font-weight: 200/font-weight: 400/g" \
					-e "s/font-weight: 100/font-weight: 400/g" \
					"${css}" || true
			fi
			if [ ! -z "${fix_font_weight:-}" ] ; then
				replace_font=sans-serif
				sed -i \
					-e "s/font-weight: 200/font-weight: 400/g" \
					-e "s/font-weight: 100/font-weight: 400/g" \
					"${css}" || true
			fi
			if [ ! -z "${THEME:-}" ] ; then
			sed -i \
				-e "s/1ed660/oomox_selected_text_color/gI" \
				-e "s/1ed760/oomox_selected_text_color/gI" \
				-e "s/1db954/oomox_selected_button_color/gI" \
				-e "s/179443/oomox_selected_button_color/gI" \
				-e "s/18ab4d/oomox_selected_button_color/gI" \
				-e "s/1df269/oomox_hover_selection_color/gI" \
				-e "s/1bd85e/oomox_hover_selection_color/gI" \
				-e "s/282828/oomox_main_bg/g" \
				-e "s/121212/oomox_main_bg/g" \
				-e "s/181818/oomox_area_bg/g" \
				-e "s/333333/oomox_selected_row_bg/g" \
				-e "s/404040/oomox_selected_area_bg/g" \
				\
				-e "s/ffffff/oomox_accent_fg/gI" \
				-e "s/fcfcfc/oomox_hover_text/gI" \
				-e "s/a0a0a0/oomox_main_fg/gI" \
				-e "s/adafb2/oomox_sidebar_fg/gI" \
				"${css}"
			sed -i \
				-e "s/oomox_main_bg/${main_bg}/g" \
				-e "s/oomox_area_bg/${area_bg}/g" \
				-e "s/oomox_selected_row_bg/${selected_row_bg}/g" \
				-e "s/oomox_selected_area_bg/${selected_area_bg}/g" \
				-e "s/oomox_accent_fg/${accent_fg}/gI" \
				-e "s/oomox_hover_text/${hover_text}/gI" \
				-e "s/oomox_selected_text_color/${selected_text_color}/gI" \
				-e "s/oomox_selected_button_color/${selected_button_color}/gI" \
				-e "s/oomox_hover_selection_color/${hover_selection_color}/gI" \
				-e "s/oomox_main_fg/${main_fg}/gI" \
				-e "s/oomox_sidebar_fg/${sidebar_fg}/gI" \
				"${css}"
			fi
			zip "./${filename}" "${css}" > /dev/null
		done
		cd "${tmp_dir}"
		mv "./${filename}" "${output_dir}/"
	fi
	rm "${tmp_dir}/"* -r
done

if [ ! -z "${gui:-}" ] ; then
	priv_tool="gksu"
else
	priv_tool="sudo"
fi
"${priv_tool}" cp "${output_dir}/"* "${spotify_apps_path}"/
