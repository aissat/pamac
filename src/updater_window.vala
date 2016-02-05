/*
 *  pamac-vala
 *
 *  Copyright (C) 2014-2016 Guillaume Benoit <guillaume@manjaro.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a get of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Pamac {

	[GtkTemplate (ui = "/org/manjaro/pamac/updater/updater_window.ui")]
	public class UpdaterWindow : Gtk.ApplicationWindow {

		[GtkChild]
		public Gtk.Label top_label;
		[GtkChild]
		//public Gtk.Notebook notebook;
		public Gtk.Stack  stack;
		[GtkChild]
		public Gtk.ScrolledWindow repos_scrolledwindow;
		[GtkChild]
		public Gtk.ScrolledWindow aur_scrolledwindow;
		[GtkChild]
		public Gtk.TreeView repos_updates_treeview;
		[GtkChild]
		public Gtk.CellRendererToggle repos_select_update;
		[GtkChild]
		public Gtk.TreeView aur_updates_treeview;
		[GtkChild]
		public Gtk.CellRendererToggle aur_select_update;
		[GtkChild]
		public Gtk.Label bottom_label;
		[GtkChild]
		public Gtk.Button apply_button;

		public Gtk.ListStore repos_updates_list;
		public Gtk.ListStore aur_updates_list;

		public Pamac.Transaction transaction;

		public UpdaterWindow (Gtk.Application application) {
			Object (application: application);

			repos_updates_list = new Gtk.ListStore (3, typeof (bool), typeof (string), typeof (string));
			repos_updates_treeview.set_model (repos_updates_list);
			aur_updates_list = new Gtk.ListStore (2, typeof (bool), typeof (string));
			aur_updates_treeview.set_model (aur_updates_list);

			transaction = new Transaction (this as Gtk.ApplicationWindow);
			transaction.mode = Mode.UPDATER;
			transaction.finished.connect (on_transaction_finished);

			transaction.daemon.get_updates_finished.connect (on_get_updates_finished);

			bottom_label.set_visible (false);
			apply_button.set_sensitive (false);

			//notebook.set_show_tabs (false);
			aur_scrolledwindow.set_visible (false);
			on_refresh_button_clicked ();
		}

		public void set_apply_button_sensitive () {
			bool sensitive = false;
			repos_updates_list.foreach ((model, path, iter) => {
				GLib.Value selected;
				repos_updates_list.get_value (iter, 0, out selected);
				sensitive = (bool) selected;
				return sensitive;
			});
			if (!sensitive) {
				aur_updates_list.foreach ((model, path, iter) => {
					GLib.Value selected;
					aur_updates_list.get_value (iter, 0, out selected);
					sensitive = (bool) selected;
					return sensitive;
				});
			}
			apply_button.set_sensitive (sensitive);
		}

		[GtkCallback]
		public void on_repos_select_update_toggled (string path) {
			Gtk.TreePath treepath = new Gtk.TreePath.from_string (path);
			Gtk.TreeIter iter;
			GLib.Value name_string;
			repos_updates_list.get_iter (out iter, treepath);
			repos_updates_list.get_value (iter, 1, out name_string);
			// string has the form "pkgname pkgversion"
			string pkgname = name_string.get_string ().split (" ", 2)[0];
			if (repos_select_update.active) {
				repos_updates_list.set (iter, 0, false);
				transaction.special_ignorepkgs.add (pkgname);
			} else {
				repos_updates_list.set (iter, 0, true);
				transaction.special_ignorepkgs.remove (pkgname);
			}
			set_apply_button_sensitive ();
		}

		[GtkCallback]
		public void on_aur_select_update_toggled  (string path) {
			Gtk.TreePath treepath = new Gtk.TreePath.from_string (path);
			Gtk.TreeIter iter;
			GLib.Value name_string;
			aur_updates_list.get_iter (out iter, treepath);
			aur_updates_list.get_value (iter, 1, out name_string);
			// string has the form "pkgname pkgversion"
			string pkgname = name_string.get_string ().split (" ", 2)[0];
			if (aur_select_update.active) {
				aur_updates_list.set (iter, 0, false);
				transaction.special_ignorepkgs.add (pkgname);
			} else {
				aur_updates_list.set (iter, 0, true);
				transaction.special_ignorepkgs.remove (pkgname);
			}
			set_apply_button_sensitive ();
		}

		public async void run_preferences_dialog () {
			SourceFunc callback = run_preferences_dialog.callback;
			ulong handler_id = transaction.daemon.get_authorization_finished.connect ((authorized) => {
				if (authorized) {
					var preferences_dialog = new PreferencesDialog (this, transaction);
					preferences_dialog.run ();
					preferences_dialog.destroy ();
					while (Gtk.events_pending ()) {
						Gtk.main_iteration ();
					}
				}
				Idle.add((owned) callback);
			});
			transaction.start_get_authorization ();
			yield;
			transaction.daemon.disconnect (handler_id);
		}

		[GtkCallback]
		public void on_preferences_button_clicked () {
			run_preferences_dialog.begin (() => {
				populate_updates_list ();
			});
		}

		[GtkCallback]
		public void on_apply_button_clicked () {
			this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
			transaction.sysupgrade (false);
		}

		[GtkCallback]
		public void on_refresh_button_clicked () {
			this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
			transaction.start_refresh (false);
		}

		[GtkCallback]
		public void on_close_button_clicked () {
			this.application.quit ();
		}

		public void on_transaction_finished (bool database_modified) {
			if (database_modified) {
				populate_updates_list ();
			} else {
				this.get_window ().set_cursor (null);
			}
		}

		public void populate_updates_list () {
			this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
			transaction.start_get_updates ();
		}

		public void on_get_updates_finished (Updates updates) {
			top_label.set_markup ("");
			repos_updates_list.clear ();
			//notebook.set_show_tabs (false);
			repos_scrolledwindow.set_visible (true);
			aur_updates_list.clear ();
			bottom_label.set_visible (false);
			Gtk.TreeIter iter;
			uint64 dsize = 0;
			uint repos_updates_nb = 0;
			uint aur_updates_nb = 0;
			foreach (unowned PackageInfos infos in updates.repos_updates) {
				string name = infos.name + " " + infos.version;
				string size = infos.download_size != 0 ? format_size (infos.download_size) : "";
				dsize += infos.download_size;
				repos_updates_nb++;
				if (infos.name in transaction.special_ignorepkgs) {
					repos_updates_list.insert_with_values (out iter, -1, 0, false, 1, name, 2, size);
				} else {
					repos_updates_list.insert_with_values (out iter, -1, 0, true, 1, name, 2, size);
				}
			}
			foreach (unowned PackageInfos infos in updates.aur_updates) {
				string name = infos.name + " " + infos.version;
				aur_updates_nb++;
				if (infos.name in transaction.special_ignorepkgs) {
					aur_updates_list.insert_with_values (out iter, -1, 0, false, 1, name);
				} else {
					aur_updates_list.insert_with_values (out iter, -1, 0, true, 1, name);
				}
			}
			uint updates_nb = repos_updates_nb + aur_updates_nb;
			if (updates_nb == 0) {
				top_label.set_markup("<b>%s</b>".printf (dgettext (null, "Your system is up-to-date")));
			} else {
				top_label.set_markup("<b>%s</b>".printf (dngettext (null, "%u available update", "%u available updates", updates_nb).printf (updates_nb)));
			}
			set_apply_button_sensitive ();
			if (dsize != 0) {
				bottom_label.set_markup("<b>%s: %s</b>".printf (dgettext (null, "Total download size"), format_size(dsize)));
				bottom_label.set_visible (true);
			} else {
				bottom_label.set_visible (false);
			}
			if (repos_updates_nb != 0) {
				//notebook.set_show_tabs (true);
			}
			if (aur_updates_nb == 0) {
				aur_scrolledwindow.set_visible (false);
			} else {
				aur_scrolledwindow.set_visible (true);
				if (repos_updates_nb == 0) {
					repos_scrolledwindow.set_visible (false);
				}
				//notebook.set_show_tabs (true);
			}
			this.get_window ().set_cursor (null);
		}
	}
}
