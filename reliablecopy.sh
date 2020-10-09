#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright (C) 2020 Caio Mehlem <caioxmag@gmail.com>

set -eu

REQUIRED_COMMANDS="
	[
	command
	cd
	cp
	echo
	exit
	getopts
	hashdeep
	mktemp
	realpath
	shift
	trap
"

e_err()
{
	echo >&2 "ERROR: ${*}"
}

e_warn()
{
	echo "WARN: ${*}"
}

ts_print()
{
	echo "$(date '+%Y-%m-%d %H:%M:%S'): ${*}"
}

usage()
{
	echo "Usage: ${0} [options] ORIGIN BACKUP_TARGET"
	echo
	echo "Reliably backup files by comparing the original and backed-up"
	echo "files using md5"
	echo "    -h  Print usage"
	echo "    -v  Verbose output: print file verification report"
}

check_requirements()
{
	for _cmd in ${REQUIRED_COMMANDS}; do
		if ! _test_result="$(command -V "${_cmd}")"; then
			_test_result_fail="${_test_result_fail:-}${_test_result}\n"
		else
			_test_result_pass="${_test_result_pass:-}${_test_result}\n"
		fi
	done

	if [ -n "${_test_result_fail:-}" ]; then
		e_err "Self-test failed, missing dependencies."
		echo "======================================="
		echo "Passed tests:"
		printf "${_test_result_pass:-none\n}"
		echo "---------------------------------------"
		echo "Failed tests:"
		printf "${_test_result_fail:-none\n}"
		echo "======================================="
		exit 1
	fi
}

cleanup()
{
	echo "Nothing to cleanup here"
	trap EXIT
}

backup()
{
	echo
	echo "================================================================================"
	echo

	ts_print "Hashing contents of "${origin_dir:-}" recursively..."
	_original_checksums=$(mktemp "/tmp/original_checksums.XXXX")
	cd "${origin_dir:-}"
	hashdeep -r -l -c md5 . > "${_original_checksums:-}"
	ts_print "    done!"

	ts_print "Backing up files from "${origin_dir:-}" to "${backup_dir:-}" recursively..."
	cp -r "${origin_dir:-}"/* "${backup_dir:-}"/
	ts_print "    done!"

	ts_print "Hashing contents of "${backup_dir:-}" recursively and comparing to original files..."
	_report=$(mktemp "/tmp/copy_report.XXXX")

	cd "${backup_dir:-}"

	if hashdeep -r -a -vv -l -k "${_original_checksums:-}" . > "${_report:-}"; then
		ts_print "    Completed successfully!"
	else
		ts_print "    Finished with errors!"
	fi

	cd "${starting_dir:-}"

	cp "${_original_checksums:-}" "${backup_dir:-}/backup_original_checksums.log"
	cp "${_report:-}" "${backup_dir:-}/backup_report.log"

	echo

	if [ -n "${verbose:-}" ]; then
		echo "================================================================================"
		echo
		cat "${_report:-}"
		echo
		echo "================================================================================"
	else
		echo "File verification report is in "${backup_dir:-}/backup_report.log""
		echo
		echo "================================================================================"
	fi
}

main()
{
	while getopts "hv" options; do
		case "${options}" in
		h)
			usage
			exit 0
			;;
		v)
			verbose="true"
			;;
		:)
			e_err "Option -${OPTARG} requires an argument."
			exit 1
			;;
		?)
			echo "Invalid option: -${OPTARG}"
			echo
			usage
			exit 1
			;;
		esac
	done
	shift "$((OPTIND - 1))"

	check_requirements

	origin_dir="$(realpath "${1:-}")"
	backup_dir="$(realpath "${2:-}")"

	if [ -z "${origin_dir:-}" ]; then
		e_err "Missing origin directory to be backed-up"
		echo
		usage
		exit 1
	fi

	if [ ! -d "${origin_dir:-}" ]; then
		e_err "Could not find origin directory: ${origin_dir:-}"
		exit 1
	fi

	if [ -z "${backup_dir:-}" ]; then
		e_err "Missing backup target directory"
		echo
		usage
		exit 1
	fi

	if [ ! -d "${backup_dir:-}" ]; then
		e_err "Could not find target directory: ${backup_dir:-}"
		exit 1
	fi

	starting_dir="$(pwd)"

	confirmation_msg="$(printf "Recursively backing up the contents of:\n    ${origin_dir}\ninto:\n    ${backup_dir}\nProceed? ")"

	read -p "${confirmation_msg}" -n 1 -r
	if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
		echo
		backup
	else
		echo "Aborting"
	fi
}

main "${@}"

echo
echo "FINISHED"

exit 0
