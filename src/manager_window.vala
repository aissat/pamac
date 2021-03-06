/*
 *  pamac-vala
 *
 *  Copyright (C) 2014-2016 Guillaume Benoit <guillaume@manjaro.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
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

	public struct SortInfo {
		public int column_number;
		public Gtk.SortType sort_type;
	}

	[GtkTemplate (ui = "/org/manjaro/pamac/manager/manager_window.ui")]
	public class ManagerWindow : Gtk.ApplicationWindow {
		// icons
		public Gdk.Pixbuf? installed_icon;
		public Gdk.Pixbuf? uninstalled_icon;
		public Gdk.Pixbuf? to_install_icon;
		public Gdk.Pixbuf? to_reinstall_icon;
		public Gdk.Pixbuf? to_remove_icon;
		public Gdk.Pixbuf? locked_icon;

		// manager objects
		[GtkChild]
		public Gtk.TreeView packages_treeview;
		[GtkChild]
		public Gtk.TreeViewColumn packages_state_column;
		[GtkChild]
		public Gtk.TreeViewColumn packages_name_column;
		[GtkChild]
		public Gtk.TreeViewColumn packages_version_column;
		[GtkChild]
		public Gtk.TreeViewColumn packages_repo_column;
		[GtkChild]
		public Gtk.TreeViewColumn packages_size_column;
		[GtkChild]
		public Gtk.TreeView aur_treeview;
		[GtkChild]
		public Gtk.ScrolledWindow aur_scrolledwindow;
		[GtkChild]
		public Gtk.TreeViewColumn aur_state_column;
		[GtkChild]
		public Gtk.TreeViewColumn aur_name_column;
		[GtkChild]
		public Gtk.TreeViewColumn aur_version_column;
		[GtkChild]
		public Gtk.TreeViewColumn aur_votes_column;
		[GtkChild]
		public Gtk.Notebook filters_notebook;
		[GtkChild]
		public Gtk.SearchEntry search_entry;
		[GtkChild]
		public Gtk.TreeView search_treeview;
		[GtkChild]
		public Gtk.TreeView groups_treeview;
		[GtkChild]
		public Gtk.TreeView states_treeview;
		[GtkChild]
		public Gtk.TreeView repos_treeview;
		[GtkChild]
		public Gtk.Notebook packages_notebook;
		[GtkChild]
		public Gtk.Notebook properties_notebook;
		[GtkChild]
		public Gtk.TreeView deps_treeview;
		[GtkChild]
		public Gtk.TreeView details_treeview;
		[GtkChild]
		public Gtk.ScrolledWindow deps_scrolledwindow;
		[GtkChild]
		public Gtk.ScrolledWindow details_scrolledwindow;
		[GtkChild]
		public Gtk.ScrolledWindow files_scrolledwindow;
		[GtkChild]
		public Gtk.Label name_label;
		[GtkChild]
		public Gtk.Label desc_label;
		[GtkChild]
		public Gtk.Label link_label;
		[GtkChild]
		public Gtk.Label licenses_label;
		[GtkChild]
		public Gtk.TextView files_textview;
		[GtkChild]
		public Gtk.Box search_aur_box;
		[GtkChild]
		public Gtk.Switch search_aur_button;
		[GtkChild]
		public Gtk.Button valid_button;
		[GtkChild]
		public Gtk.Button cancel_button;

		// menu
		Gtk.Menu right_click_menu;
		Gtk.MenuItem deselect_item;
		Gtk.MenuItem install_item;
		Gtk.MenuItem remove_item;
		Gtk.MenuItem reinstall_item;
		Gtk.MenuItem install_optional_deps_item;
		Gtk.MenuItem explicitly_installed_item;
		Alpm.List<unowned Alpm.Package?> selected_pkgs;
		GLib.List<unowned Json.Object> selected_aur;

		// liststore
		Gtk.ListStore search_list;
		Gtk.ListStore groups_list;
		Gtk.ListStore states_list;
		Gtk.ListStore repos_list;
		Gtk.ListStore deps_list;
		Gtk.ListStore details_list;

		PackagesModel packages_list;
		AURModel aur_list;

		public HashTable<string,Json.Array> aur_search_results;

		public Alpm.Config alpm_config;

		public Transaction transaction;

		public SortInfo sortinfo;

		public ManagerWindow (Gtk.Application application) {
			Object (application: application);

			right_click_menu = new Gtk.Menu ();
			deselect_item = new Gtk.MenuItem.with_label (dgettext (null, "Deselect"));
			deselect_item.activate.connect (on_deselect_item_activate);
			right_click_menu.append (deselect_item);
			install_item = new Gtk.MenuItem.with_label (dgettext (null, "Install"));
			install_item.activate.connect (on_install_item_activate);
			right_click_menu.append (install_item);
			remove_item = new Gtk.MenuItem.with_label (dgettext (null, "Remove"));
			remove_item.activate.connect (on_remove_item_activate);
			right_click_menu.append (remove_item);
			var separator_item = new Gtk.SeparatorMenuItem ();
			right_click_menu.append (separator_item);
			reinstall_item = new Gtk.MenuItem.with_label (dgettext (null, "Reinstall"));
			reinstall_item.activate.connect (on_reinstall_item_activate);
			right_click_menu.append (reinstall_item);
			install_optional_deps_item = new Gtk.MenuItem.with_label (dgettext (null, "Install optional dependencies"));
			install_optional_deps_item.activate.connect (on_install_optional_deps_item_activate);
			right_click_menu.append (install_optional_deps_item);
			explicitly_installed_item = new Gtk.MenuItem.with_label (dgettext (null, "Mark as explicitly installed"));
			explicitly_installed_item.activate.connect (on_explicitly_installed_item_activate);
			right_click_menu.append (explicitly_installed_item);
			right_click_menu.show_all ();

			search_list = new Gtk.ListStore (1, typeof (string));
			search_treeview.set_model (search_list);
			groups_list = new Gtk.ListStore (1, typeof (string));
			groups_treeview.set_model (groups_list);
			states_list = new Gtk.ListStore (1, typeof (string));
			states_treeview.set_model (states_list);
			repos_list = new Gtk.ListStore (1, typeof (string));
			repos_treeview.set_model (repos_list);
			deps_list = new Gtk.ListStore (2, typeof (string), typeof (string));
			deps_treeview.set_model (deps_list);
			details_list = new Gtk.ListStore (2, typeof (string), typeof (string));
			details_treeview.set_model (details_list);

			try {
				installed_icon = new Gdk.Pixbuf.from_resource ("/org/manjaro/pamac/manager/package-installed-updated.png");
				uninstalled_icon = new Gdk.Pixbuf.from_resource ("/org/manjaro/pamac/manager/package-available.png");
				to_install_icon = new Gdk.Pixbuf.from_resource ("/org/manjaro/pamac/manager/package-install.png");
				to_reinstall_icon = new Gdk.Pixbuf.from_resource ("/org/manjaro/pamac/manager/package-reinstall.png");
				to_remove_icon = new Gdk.Pixbuf.from_resource ("/org/manjaro/pamac/manager/package-remove.png");
				locked_icon = new Gdk.Pixbuf.from_resource ("/org/manjaro/pamac/manager/package-installed-locked.png");
			} catch (GLib.Error e) {
				stderr.printf (e.message);
			}

			transaction = new Transaction (this as Gtk.ApplicationWindow);
			transaction.mode = Mode.MANAGER;
			transaction.finished.connect (on_transaction_finished);
			transaction.daemon.write_pamac_config_finished.connect (on_write_pamac_config_finished);
			transaction.daemon.set_pkgreason_finished.connect (display_package_properties);

			alpm_config = new Alpm.Config ("/etc/pacman.conf");
			refresh_handle ();

			unowned Alpm.Package? pkg = Alpm.find_satisfier (alpm_config.handle.localdb.pkgcache, "yaourt");
			if (pkg == null) {
				support_aur (false, false);
			} else {
				support_aur (transaction.pamac_config.enable_aur, transaction.pamac_config.search_aur);
			}

			set_buttons_sensitive (false);

			// sort by name by default
			sortinfo = {0, Gtk.SortType.ASCENDING};

			aur_search_results = new HashTable<string,Json.Array> (str_hash, str_equal);

			update_lists ();
			show_default_pkgs ();
		}

		void on_write_pamac_config_finished (bool recurse, uint64 refresh_period, bool no_update_hide_icon,
											bool enable_aur, bool search_aur) {
			if (recurse) {
				transaction.flags |= Alpm.TransFlag.RECURSE;
			}
			unowned Alpm.Package? pkg = Alpm.find_satisfier (alpm_config.handle.localdb.pkgcache, "yaourt");
			if (pkg != null) {
				support_aur (enable_aur, search_aur);
			}
		}

		public void support_aur (bool enable_aur, bool search_aur) {
			if (enable_aur) {
				search_aur_button.set_active (search_aur);
				search_aur_box.set_visible (true);
				aur_scrolledwindow.set_visible (true);
			} else {
				search_aur_button.set_active (false);
				search_aur_box.set_visible (false);
				aur_scrolledwindow.set_visible (false);
			}
		}

		public void set_buttons_sensitive (bool sensitive) {
			valid_button.set_sensitive (sensitive);
			cancel_button.set_sensitive (sensitive);
		}

		public void refresh_handle () {
			alpm_config.get_handle ();
			if (alpm_config.handle == null) {
				stderr.printf (dgettext (null, "Failed to initialize alpm library"));
			}
		}

		public async Alpm.List<unowned Alpm.Package?> search_all_dbs (string search_string) {
			var syncpkgs = new Alpm.List<unowned Alpm.Package?> ();
			var needles = new Alpm.List<unowned string> ();
			string[] splitted = search_string.split (" ");
			foreach (unowned string part in splitted) {
				needles.add (part);
			}
			var result = alpm_config.handle.localdb.search (needles);
			foreach (var db in alpm_config.handle.syncdbs) {
				if (syncpkgs.length == 0) {
					syncpkgs = db.search (needles);
				} else {
					syncpkgs.join (db.search (needles).diff (syncpkgs, (Alpm.List.CompareFunc) compare_name));
				}
			}
			result.join (syncpkgs.diff (result, (Alpm.List.CompareFunc) compare_name));
			//result.sort ((Alpm.List.CompareFunc) compare_name);
			return result;
		}

		public async Alpm.List<unowned Alpm.Package?> get_group_pkgs (string grp_name) {
			var result = new Alpm.List<unowned Alpm.Package?> ();
			unowned Alpm.Group? grp = alpm_config.handle.localdb.get_group (grp_name);
			if (grp != null) {
				foreach (var pkg in grp.packages) {
					result.add (pkg);
				}
			}
			result.join (Alpm.find_group_pkgs (alpm_config.handle.syncdbs, grp_name).diff (result, (Alpm.List.CompareFunc) compare_name));
			//result.sort ((Alpm.List.CompareFunc) compare_name);
			return result;
		}

		public async Alpm.List<unowned Alpm.Package?> get_installed_pkgs () {
			return alpm_config.handle.localdb.pkgcache.copy ();
		}

		public async Alpm.List<unowned Alpm.Package?> get_orphans () {
			var result = new Alpm.List<unowned Alpm.Package?> ();
			foreach (var pkg in alpm_config.handle.localdb.pkgcache) {
				if (pkg.reason == Alpm.Package.Reason.DEPEND) {
					Alpm.List<string?> requiredby = pkg.compute_requiredby ();
					if (requiredby.length == 0) {
						Alpm.List<string?> optionalfor = pkg.compute_optionalfor ();
						if (optionalfor.length == 0) {
							result.add (pkg);
						}
						optionalfor.free_data ();
					}
					requiredby.free_data ();
				}
			}
			return result;
		}

		public async Alpm.List<unowned Alpm.Package?> get_local_pkgs () {
			var result = new Alpm.List<unowned Alpm.Package?> ();
			foreach (var pkg in alpm_config.handle.localdb.pkgcache) {
				if (get_sync_pkg (pkg.name) == null) {
					result.add (pkg);
				}
			}
			return result;
		}

		public async Alpm.List<unowned Alpm.Package?> get_repo_pkgs (string reponame) {
			var result = new Alpm.List<unowned Alpm.Package?> ();
			foreach (var db in alpm_config.handle.syncdbs) {
				if (db.name == reponame) {
					foreach (var sync_pkg in db.pkgcache) {
						unowned Alpm.Package?local_pkg = alpm_config.handle.localdb.get_pkg (sync_pkg.name);
						if (local_pkg != null) {
							result.add (local_pkg);
						} else {
							result.add (sync_pkg);
						}
					}
				}
			}
			return result;
		}

//~ 		public async Alpm.List<unowned Alpm.Package?> get_all_pkgs () {
//~ 			var syncpkgs = new Alpm.List<unowned Alpm.Package?> ();
//~ 			var result = new Alpm.List<unowned Alpm.Package?> ();
//~ 			result = alpm_config.handle.localdb.pkgcache.copy ();
//~ 			foreach (var db in alpm_config.handle.syncdbs) {
//~ 				if (syncpkgs.length == 0)
//~ 					syncpkgs = db.pkgcache.copy ();
//~ 				else {
//~ 					syncpkgs.join (db.pkgcache.diff (syncpkgs, (Alpm.List.CompareFunc) compare_name));
//~ 				}
//~ 			}
//~ 			result.join (syncpkgs.diff (result, (Alpm.List.CompareFunc) compare_name));
//~ 			//result.sort ((Alpm.List.CompareFunc) compare_name);
//~ 			return result;
//~ 		}

		public unowned Alpm.Package? get_sync_pkg (string pkgname) {
			unowned Alpm.Package? pkg = null;
			foreach (var db in alpm_config.handle.syncdbs) {
				pkg = db.get_pkg (pkgname);
				if (pkg != null) {
					break;
				}
			}
			return pkg;
		}

		public void show_default_pkgs () {
			this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
			get_installed_pkgs.begin ((obj, res) => {
				var pkgs = get_installed_pkgs.end (res);
				populate_packages_list ((owned) pkgs);
			});
		}

		public void update_lists () {
			Gtk.TreeIter iter;
			Gtk.TreeSelection selection;
			selection = repos_treeview.get_selection ();
			selection.changed.disconnect (on_repos_treeview_selection_changed);
			var groups_names = new GLib.List<string> ();
			foreach (var db in alpm_config.handle.syncdbs) {
				repos_list.insert_with_values (out iter, -1, 0, db.name);
				foreach (var group in db.groupcache) {
					if (groups_names.find_custom (group.name, strcmp) == null) {
						groups_names.append (group.name);
					}
				}
			}
			repos_list.insert_with_values (out iter, -1, 0, dgettext (null, "local"));
			repos_list.get_iter_first (out iter);
			selection.select_iter (iter);
			selection.changed.connect_after (on_repos_treeview_selection_changed);

			selection = groups_treeview.get_selection ();
			selection.changed.disconnect (on_groups_treeview_selection_changed);
			foreach (var group in alpm_config.handle.localdb.groupcache) {
				if (groups_names.find_custom (group.name, strcmp) == null) {
					groups_names.append (group.name);
				}
			}
			foreach (unowned string group_name in groups_names) {
				groups_list.insert_with_values (out iter, -1, 0, group_name);
			}
			groups_list.set_sort_column_id (0, Gtk.SortType.ASCENDING);
			groups_list.get_iter_first (out iter);
			selection.select_iter (iter);
			selection.changed.connect_after (on_groups_treeview_selection_changed);

			selection = states_treeview.get_selection ();
			selection.changed.disconnect (on_states_treeview_selection_changed);
			states_list.insert_with_values (out iter, -1, 0, dgettext (null, "Installed"));
			//states_list.insert_with_values (out iter, -1, 0, dgettext (null, "Uninstalled"));
			states_list.insert_with_values (out iter, -1, 0, dgettext (null, "Orphans"));
			states_list.insert_with_values (out iter, -1, 0, dgettext (null, "To install"));
			states_list.insert_with_values (out iter, -1, 0, dgettext (null, "To remove"));
			states_list.get_iter_first (out iter);
			selection.select_iter (iter);
			selection.changed.connect_after (on_states_treeview_selection_changed);
		}

		public void set_package_infos_list (Alpm.Package pkg) {
			name_label.set_markup ("<big><b>%s  %s</b></big>".printf (pkg.name, pkg.version));
			desc_label.set_markup (Markup.escape_text (pkg.desc));
			string url = Markup.escape_text (pkg.url);
			link_label.set_markup ("<a href=\"%s\">%s</a>".printf (url, url));
			StringBuilder licenses = new StringBuilder ();
			licenses.append (dgettext (null, "Licenses"));
			licenses.append (": ");
			foreach (unowned string license in pkg.licenses) {
				if (licenses.len != 0) {
					licenses.append (" ");
				}
				licenses.append (license);
			}
			licenses_label.set_markup (licenses.str);
		}

		public void set_aur_infos_list (Json.Object pkg_info) {
			name_label.set_markup ("<big><b>%s  %s</b></big>".printf (pkg_info.get_string_member ("Name"),
																				pkg_info.get_string_member ("Version")));
			desc_label.set_markup (Markup.escape_text (pkg_info.get_string_member ("Description")));
			string url = Markup.escape_text (pkg_info.get_string_member ("URL") ?? "");
			string aur_url = "http://aur.archlinux.org/packages/" + pkg_info.get_string_member ("Name");
			link_label.set_markup ("<a href=\"%s\">%s</a>\n\n<a href=\"%s\">%s</a>".printf (url, url, aur_url, aur_url));
			StringBuilder licenses = new StringBuilder ();
			licenses.append (dgettext (null, "Licenses"));
			licenses.append (": ");
			licenses.append (pkg_info.get_string_member ("License") ?? dgettext (null, "Unknown"));
			licenses_label.set_markup (licenses.str);
		}

		public void set_package_deps_list (Alpm.Package pkg) {
			deps_list.clear ();
			Gtk.TreeIter iter;
			unowned Alpm.List<unowned Alpm.Depend> deps = pkg.depends;
			unowned Alpm.List<unowned Alpm.Depend>? list;
			if (deps.length != 0) {
				list = deps;
				deps_list.insert_with_values (out iter, -1,
												0, dgettext (null, "Depends On") + ":",
												1, list.data.compute_string ());
				for (list = list.next (); list != null; list = list.next ()) {
					deps_list.insert_with_values (out iter, -1,
												1, list.data.compute_string ());
				}
			}
			deps = pkg.optdepends;
			if (deps.length != 0) {
				list = deps;
				string optdep_str = list.data.compute_string ();
				var optdep = new StringBuilder (optdep_str);
				if (Alpm.find_satisfier (alpm_config.handle.localdb.pkgcache, optdep_str) != null) {
					optdep.append (" [");
					optdep.append (dgettext (null, "Installed"));
					optdep.append ("]");
				}
				deps_list.insert_with_values (out iter, -1,
											0, dgettext (null, "Optional Dependencies") + ":",
											1, optdep.str);
				for (list = list.next (); list != null; list = list.next ()) {
					optdep_str = list.data.compute_string ();
					optdep = new StringBuilder (optdep_str);
					if (Alpm.find_satisfier (alpm_config.handle.localdb.pkgcache, optdep_str) != null) {
						optdep.append (" [");
						optdep.append (dgettext (null, "Installed"));
						optdep.append ("]");
					}
					deps_list.insert_with_values (out iter, -1, 1, optdep.str);
				}
			}
			if (pkg.origin == Alpm.Package.From.LOCALDB) {
				Alpm.List<string> requiredby = pkg.compute_requiredby ();
				unowned Alpm.List<string>? list2;
				if (requiredby.length != 0) {
					list2 = requiredby;
					deps_list.insert_with_values (out iter, -1,
													0, dgettext (null, "Required By") + ":",
													1, list2.data);
					for (list2 = list2.next (); list2 != null; list2 = list2.next ()) {
						deps_list.insert_with_values (out iter, -1,
													1, list2.data);
					}
				}
				requiredby.free_data ();
				Alpm.List<string> optionalfor = pkg.compute_optionalfor ();
				if (optionalfor.length != 0) {
					list2 = optionalfor;
					deps_list.insert_with_values (out iter, -1,
													0, dgettext (null, "Optional For") + ":",
													1, list2.data);
					for (list2 = list2.next (); list2 != null; list2 = list2.next ()) {
						deps_list.insert_with_values (out iter, -1,
													1, list2.data);
					}
				}
				optionalfor.free_data ();
			}
			deps = pkg.provides;
			if (deps.length != 0) {
				list = deps;
				deps_list.insert_with_values (out iter, -1,
												0, dgettext (null, "Provides") + ":",
												1, list.data.compute_string ());
				for (list = list.next (); list != null; list = list.next ()) {
					deps_list.insert_with_values (out iter, -1,
												1, list.data.compute_string ());
				}
			}
			deps = pkg.replaces;
			if (deps.length != 0) {
				list = deps;
				deps_list.insert_with_values (out iter, -1,
												0, dgettext (null, "Replaces") + ":",
												1, list.data.compute_string ());
				for (list = list.next (); list != null; list = list.next ()) {
					deps_list.insert_with_values (out iter, -1,
												1, list.data.compute_string ());
				}
			}
			deps = pkg.conflicts;
			if (deps.length != 0) {
				list = deps;
				deps_list.insert_with_values (out iter, -1,
												0, dgettext (null, "Conflicts With") + ":",
												1, list.data.compute_string ());
				for (list = list.next (); list != null; list = list.next ()) {
					deps_list.insert_with_values (out iter, -1,
												1, list.data.compute_string ());
				}
			}
		}

		public void set_package_details_list (Alpm.Package pkg) {
			details_list.clear ();
			Gtk.TreeIter iter;
			if (pkg.origin == Alpm.Package.From.SYNCDB) {
				details_list.insert_with_values (out iter, -1,
												0, dgettext (null, "Repository") + ":",
												1, pkg.db.name);
			}
			unowned Alpm.List<unowned string> groups = pkg.groups;
			if (groups.length != 0) {
				unowned Alpm.List<unowned string>? list = groups;
				details_list.insert_with_values (out iter, -1,
												0, dgettext (null, "Groups") + ":",
												1, list.data);
				for (list = list.next (); list != null; list = list.next ()) {
					details_list.insert_with_values (out iter, -1,
												1, list.data);
				}
			}
			details_list.insert_with_values (out iter, -1,
											0, dgettext (null, "Packager") + ":",
											1, pkg.packager);
			GLib.Time time = GLib.Time.local ((time_t) pkg.builddate);
			string build_date = time.format ("%a %d %b %Y %X %Z");
			details_list.insert_with_values (out iter, -1,
											0, dgettext (null, "Build Date") + ":",
											1, build_date);
			if (pkg.origin == Alpm.Package.From.LOCALDB) {
				time = GLib.Time.local ((time_t) pkg.installdate);
				string install_date = time.format ("%a %d %b %Y %X %Z");
				details_list.insert_with_values (out iter, -1,
												0, dgettext (null, "Install Date") + ":",
												1, install_date);
				string reason;
				if (pkg.reason == Alpm.Package.Reason.EXPLICIT) {
					reason = dgettext (null, "Explicitly installed");
				} else if (pkg.reason == Alpm.Package.Reason.DEPEND) {
					reason = dgettext (null, "Installed as a dependency for another package");
				} else {
					reason = dgettext (null, "Unknown");
				}
				details_list.insert_with_values (out iter, -1,
												0, dgettext (null, "Install Reason") + ":",
												1, reason);
			}
			if (pkg.origin == Alpm.Package.From.SYNCDB) {
				string has_signature = pkg.base64_sig != null ? dgettext (null, "Yes") : dgettext (null, "No");
				details_list.insert_with_values (out iter, -1,
												0, dgettext (null, "Signatures") + ":",
												1, has_signature);
			}
			if (pkg.origin == Alpm.Package.From.LOCALDB) {
				unowned Alpm.List<unowned Alpm.Backup> backups = pkg.backups;
				if (backups.length != 0) {
					unowned Alpm.List<unowned Alpm.Backup>? list = backups;
					details_list.insert_with_values (out iter, -1,
													0, dgettext (null, "Backup files") + ":",
													1, "/" + list.data.name);
					for (list = list.next (); list != null; list = list.next ()) {
						details_list.insert_with_values (out iter, -1,
													1, "/" + list.data.name);
					}
				}
			}
		}

		public void set_aur_details_list (Json.Object pkg_info) {
			details_list.clear ();
			Gtk.TreeIter iter;
			details_list.insert_with_values (out iter, -1,
													0, dgettext (null, "Maintainer") + ":",
													1, pkg_info.get_string_member ("Maintainer"));
			GLib.Time time = GLib.Time.local ((time_t) pkg_info.get_int_member ("FirstSubmitted"));
			details_list.insert_with_values (out iter, -1,
													0, dgettext (null, "First Submitted") + ":",
													1, time.format ("%a %d %b %Y %X %Z"));
			time = GLib.Time.local ((time_t) pkg_info.get_int_member ("LastModified"));
			details_list.insert_with_values (out iter, -1,
													0, dgettext (null, "Last Modified") + ":",
													1, time.format ("%a %d %b %Y %X %Z"));
			details_list.insert_with_values (out iter, -1,
													0, dgettext (null, "Votes") + ":",
													1, pkg_info.get_int_member ("NumVotes").to_string ());
			if (!pkg_info.get_null_member ("OutOfDate")) {
				time = GLib.Time.local ((time_t) pkg_info.get_int_member ("OutOfDate"));
				details_list.insert_with_values (out iter, -1,
													0, dgettext (null, "Out of Date") + ":",
													1, time.format ("%a %d %b %Y %X %Z"));
			}
		}

		public void set_package_files_list (Alpm.Package pkg) {
			StringBuilder text = new StringBuilder (); 
			foreach (var file in pkg.files) {
				if (text.len != 0) {
					text.append ("\n");
				}
				text.append ("/");
				text.append (file.name);
			}
			files_textview.buffer.set_text (text.str, (int) text.len);
		}

		public void populate_packages_list (owned Alpm.List<unowned Alpm.Package?>? pkgs) {
			packages_treeview.freeze_child_notify ();
			packages_treeview.set_model (null);

			// populate liststore
			packages_list = new PackagesModel ((owned) pkgs, this);

			// sort liststore
			int column = sortinfo.column_number;
			switch (column) {
				case 0:
					packages_list.sort_by_name (sortinfo.sort_type);
					break;
				case 1:
					packages_list.sort_by_state (sortinfo.sort_type);
					break;
				case 2:
					packages_list.sort_by_version (sortinfo.sort_type);
					break;
				case 3:
					packages_list.sort_by_repo (sortinfo.sort_type);
					break;
				case 4:
					packages_list.sort_by_size (sortinfo.sort_type);
					break;
				default:
					break;
			}

			packages_treeview.set_model (packages_list);
			packages_treeview.thaw_child_notify ();

			this.get_window ().set_cursor (null);
		}

		public void populate_aur_list (Json.Array? pkgs_infos) {
			aur_treeview.freeze_child_notify ();
			aur_treeview.set_model (null);

			// populate liststore
			aur_list = new AURModel (pkgs_infos, this);

			// sort liststore
			int column = sortinfo.column_number;
			switch (column) {
				case 0:
					aur_list.sort_by_name (sortinfo.sort_type);
					break;
				case 1:
					aur_list.sort_by_state (sortinfo.sort_type);
					break;
				case 2:
					aur_list.sort_by_version (sortinfo.sort_type);
					break;
				case 3:
					aur_list.sort_by_votes (sortinfo.sort_type);
					break;
				default:
					break;
			}

			aur_treeview.set_model (aur_list);
			aur_treeview.thaw_child_notify ();

			this.get_window ().set_cursor (null);
		}

		public void refresh_packages_list () {
			switch (filters_notebook.get_current_page ()) {
				case 0:
					if (search_aur_button.get_active ()) {
						aur_scrolledwindow.set_visible (true);
					}
					Gtk.TreeSelection selection = search_treeview.get_selection ();
					if (selection.get_selected (null, null)) {
						on_search_treeview_selection_changed ();
					} else {
						show_default_pkgs ();
					}
					break;
				case 1:
					aur_scrolledwindow.set_visible (false);
					on_groups_treeview_selection_changed ();
					break;
				case 2:
					aur_scrolledwindow.set_visible (false);
					on_states_treeview_selection_changed ();
					break;
				case 3:
					aur_scrolledwindow.set_visible (false);
					on_repos_treeview_selection_changed ();
					break;
				default:
					break;
			}
		}

		public void display_package_properties () {
			switch (packages_notebook.get_current_page ()) {
				case 0:
					Gtk.TreeSelection selection = packages_treeview.get_selection ();
					GLib.List<Gtk.TreePath> selected = selection.get_selected_rows (null);
					if (selected.length () > 0) {
						// display info for the first package of the selection
						unowned Alpm.Package? pkg = packages_list.get_pkg_at_path (selected.nth_data (0));
						if (pkg == null) {
							return;
						}
						if (pkg.origin == Alpm.Package.From.LOCALDB) {
							files_scrolledwindow.visible = true;
						} else {
							files_scrolledwindow.visible = false;
						}
						switch (properties_notebook.get_current_page ()) {
							case 0:
								set_package_infos_list (pkg);
								deps_scrolledwindow.visible = true;
								break;
							case 1:
								set_package_deps_list (pkg);
								break;
							case 2:
								set_package_details_list (pkg);
								deps_scrolledwindow.visible = true;
								break;
							case 3:
								if (pkg.origin == Alpm.Package.From.LOCALDB) {
									set_package_files_list (pkg);
								}
								break;
							default:
								break;
						}
					}
					break;
				case 1:
					Gtk.TreeSelection selection = aur_treeview.get_selection ();
					GLib.List<Gtk.TreePath> selected = selection.get_selected_rows (null);
					if (selected.length () > 0) {
						// display info for the first package of the selection
						unowned Json.Object? pkg_info = aur_list.get_pkg_at_path (selected.nth_data (0));
						if (pkg_info == null) {
							return;
						}
						unowned Alpm.Package? pkg = alpm_config.handle.localdb.get_pkg (pkg_info.get_string_member ("Name"));
						if (pkg != null) {
							files_scrolledwindow.visible = true;
							switch (properties_notebook.get_current_page ()) {
								case 0:
									set_package_infos_list (pkg);
									deps_scrolledwindow.visible = true;
									break;
								case 1:
									set_package_deps_list (pkg);
									break;
								case 2:
									set_package_details_list (pkg);
									deps_scrolledwindow.visible = true;
									break;
								case 3:
									set_package_files_list (pkg);
									break;
								default:
									break;
							}
						} else {
							files_scrolledwindow.visible = false;
							deps_scrolledwindow.visible = false;
							switch (properties_notebook.get_current_page ()) {
								case 0:
									set_aur_infos_list (pkg_info);
									break;
								case 1:
									break;
								case 2:
									set_aur_details_list (pkg_info);
									break;
								case 3:
									break;
								default:
									break;
							}
							break;
						}
					}
					break;
				default:
					break;
			}
		}

		[GtkCallback]
		public void on_packages_treeview_selection_changed () {
			display_package_properties ();
		}

		[GtkCallback]
		public void on_aur_treeview_selection_changed () {
			display_package_properties ();
		}

		[GtkCallback]
		public void on_properties_notebook_switch_page (Gtk.Widget page, uint page_num) {
			display_package_properties ();
		}

		[GtkCallback]
		public void on_packages_treeview_row_activated (Gtk.TreeView treeview, Gtk.TreePath path, Gtk.TreeViewColumn column) {
			unowned Alpm.Package? pkg = packages_list.get_pkg_at_path (path);
			if (pkg != null) {
				if (transaction.to_add.remove (pkg.name)) {
				} else if (transaction.to_remove.remove (pkg.name)) {
				} else {
					if (pkg.origin == Alpm.Package.From.LOCALDB) {
						if (alpm_config.holdpkgs.find_custom (pkg.name, strcmp) == null) {
							transaction.to_remove.add (pkg.name);
						}
					} else {
						transaction.to_add.add (pkg.name);
					}
				}
			}
			if ((transaction.to_add.length == 0) && (transaction.to_remove.length == 0)) {
				set_buttons_sensitive (false);
			} else {
				set_buttons_sensitive (true);
			}
			// force a display refresh
			packages_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_aur_treeview_row_activated (Gtk.TreeView treeview, Gtk.TreePath path, Gtk.TreeViewColumn column) {
			unowned Json.Object? pkg_info = aur_list.get_pkg_at_path (path);
			if (pkg_info != null) {
				unowned Alpm.Package? pkg = alpm_config.handle.localdb.get_pkg (pkg_info.get_string_member ("Name"));
				if (pkg != null) {
					if (pkg.origin == Alpm.Package.From.LOCALDB) {
						if (alpm_config.holdpkgs.find_custom (pkg.name, strcmp) == null) {
							transaction.to_remove.add (pkg.name);
						}
					}
				} else if (transaction.to_build.remove (pkg_info.get_string_member ("Name"))) {
				} else {
					transaction.to_build.add (pkg_info.get_string_member ("Name"));
				}
			}
			if ((transaction.to_build.length == 0) && (transaction.to_remove.length == 0)) {
				set_buttons_sensitive (false);
			} else {
				set_buttons_sensitive (true);
			}
			// force a display refresh
			aur_treeview.queue_draw ();
		}

		void on_install_item_activate () {
			foreach (var pkg in selected_pkgs) {
				if (pkg.origin == Alpm.Package.From.SYNCDB) {
					transaction.to_add.add (pkg.name);
				}
			}
			foreach (var pkg_info in selected_aur) {
				transaction.to_build.add (pkg_info.get_string_member ("Name"));
			}
			if (transaction.to_add.length != 0 || transaction.to_build.length != 0) {
				set_buttons_sensitive (true);
			}
		}

		void on_reinstall_item_activate () {
			foreach (var pkg in selected_pkgs) {
				transaction.to_remove.remove (pkg.name);
				if (pkg.origin == Alpm.Package.From.LOCALDB) {
					transaction.to_add.add (pkg.name);
				}
			}
			if (transaction.to_add.length != 0) {
				set_buttons_sensitive (true);
			}
		}

		void on_remove_item_activate () {
			foreach (var pkg in selected_pkgs) {
				transaction.to_add.remove (pkg.name);
				if (alpm_config.holdpkgs.find_custom (pkg.name, strcmp) == null) {
					if (pkg.origin == Alpm.Package.From.LOCALDB) {
						transaction.to_remove.add (pkg.name);
					}
				}
			}
			if (transaction.to_remove.length != 0) {
				set_buttons_sensitive (true);
			}
		}

		void on_deselect_item_activate () {
			foreach (var pkg in selected_pkgs) {
				if (transaction.to_add.remove (pkg.name)) {
				} else {
					transaction.to_remove.remove (pkg.name);
				}
			}
			foreach (var pkg_info in selected_aur) {
				transaction.to_build.remove (pkg_info.get_string_member ("Name"));
			}
			if ((transaction.to_add.length == 0)
				&& (transaction.to_remove.length == 0)
				&& (transaction.to_load.length == 0)
				&& (transaction.to_build.length == 0)) {
				set_buttons_sensitive (false);
			}
		}

		public void choose_opt_dep (Alpm.List<unowned Alpm.Package?> pkgs) {
			foreach (var pkg in pkgs) {
				var choose_dep_dialog = new ChooseDependenciesDialog (this);
				Gtk.TreeIter iter;
				int length = 0;
				foreach (var optdep in pkg.optdepends) {
					if (Alpm.find_satisfier (alpm_config.handle.localdb.pkgcache, optdep.name) == null) {
						length++;
					}
					choose_dep_dialog.deps_list.insert_with_values (out iter, -1,
											0, false,
											1, optdep.name,
											2, optdep.desc);
				}
				choose_dep_dialog.label.set_markup ("<b>%s</b>".printf (
					dngettext (null, "%s has %u uninstalled optional dependency.\nChoose if you would like to install it",
							"%s has %u uninstalled optional dependencies.\nChoose those you would like to install", length).printf (pkg.name, length)));
				if (choose_dep_dialog.run () == Gtk.ResponseType.OK) {
					choose_dep_dialog.deps_list.foreach ((model, path, iter) => {
						GLib.Value val;
						choose_dep_dialog.deps_list.get_value (iter, 0, out val);
						bool selected = val.get_boolean ();
						if (selected) {
							choose_dep_dialog.deps_list.get_value (iter, 1, out val);
							unowned Alpm.Package? sync_pkg = get_sync_pkg (val.get_string ());
							if (sync_pkg != null) {
								transaction.to_add.add (sync_pkg.name);
							}
						}
						return false;
					});
				}
				choose_dep_dialog.destroy ();
				while (Gtk.events_pending ()) {
					Gtk.main_iteration ();
				}
			}
		}

		void on_install_optional_deps_item_activate () {
			choose_opt_dep (selected_pkgs);
			if (transaction.to_add.length != 0) {
				set_buttons_sensitive (true);
			}
		}

		void on_explicitly_installed_item_activate () {
			foreach (var pkg in selected_pkgs) {
				transaction.start_set_pkgreason (pkg.name, Alpm.Package.Reason.EXPLICIT);
			}
			refresh_packages_list ();
		}


		public async void search_in_aur (string search_string) {
			if (!aur_search_results.contains (search_string)) {
				Json.Array results = AUR.search (search_string.split (" "));
				aur_search_results.insert (search_string, results);
			}
		}

		[GtkCallback]
		public void on_packages_notebook_switch_page (Gtk.Widget page, uint page_num) {
			refresh_packages_list ();
		}

		[GtkCallback]
		public bool on_packages_treeview_button_press_event (Gdk.EventButton event) {
			packages_treeview.grab_focus ();
			// Check if right mouse button was clicked
			if (event.type == Gdk.EventType.BUTTON_PRESS && event.button == 3) {
				Gtk.TreePath? treepath;
				unowned Alpm.Package? clicked_pkg;
				Gtk.TreeSelection selection = packages_treeview.get_selection ();
				packages_treeview.get_path_at_pos ((int) event.x, (int) event.y, out treepath, null, null, null);
				clicked_pkg = packages_list.get_pkg_at_path (treepath);
				if (clicked_pkg == null) {
					return true;
				}
				if (!selection.path_is_selected (treepath)) {
					selection.unselect_all ();
					selection.select_path (treepath);
				}
				GLib.List<Gtk.TreePath> selected_paths = selection.get_selected_rows (null);
				deselect_item.set_sensitive (false);
				install_item.set_sensitive (false);
				remove_item.set_sensitive (false);
				reinstall_item.set_sensitive (false);
				install_optional_deps_item.set_sensitive (false);
				explicitly_installed_item.set_sensitive (false);
				selected_pkgs = new Alpm.List<unowned Alpm.Package?> ();
				foreach (unowned Gtk.TreePath path in selected_paths) {
					selected_pkgs.add (packages_list.get_pkg_at_path (path));
				}
				foreach (var pkg in selected_pkgs) {
					if (transaction.to_add.contains (pkg.name)
							|| transaction.to_remove.contains (pkg.name)) {
						deselect_item.set_sensitive (true);
						break;
					}
				}
				foreach (var pkg in selected_pkgs) {
					if (pkg.origin == Alpm.Package.From.SYNCDB) {
						install_item.set_sensitive (true);
						break;
					}
				}
				foreach (var pkg in selected_pkgs) {
					if (pkg.origin == Alpm.Package.From.LOCALDB) {
						remove_item.set_sensitive (true);
						break;
					}
				}
				if (selected_pkgs.length == 1) {
					clicked_pkg = selected_pkgs.data;
					if (clicked_pkg.origin == Alpm.Package.From.LOCALDB) {
						foreach (var optdep in clicked_pkg.optdepends) {
							if (Alpm.find_satisfier (alpm_config.handle.localdb.pkgcache, optdep.name) == null) {
								install_optional_deps_item.set_sensitive (true);
								break;
							}
						}
						if (clicked_pkg.reason == Alpm.Package.Reason.DEPEND) {
							explicitly_installed_item.set_sensitive (true);
						}
						unowned Alpm.Package? find_pkg = get_sync_pkg (clicked_pkg.name);
						if (find_pkg != null) {
							if (Alpm.pkg_vercmp (find_pkg.version, clicked_pkg.version) == 0) {
								reinstall_item.set_sensitive (true);
							}
						}
					}
				}
				right_click_menu.popup (null, null, null, event.button, event.time);
				return true;
			} else {
				return false;
			}
		}

		[GtkCallback]
		public bool on_aur_treeview_button_press_event (Gdk.EventButton event) {
			aur_treeview.grab_focus ();
			// Check if right mouse button was clicked
			if (event.type == Gdk.EventType.BUTTON_PRESS && event.button == 3) {
				Gtk.TreePath? treepath;
				unowned Json.Object? clicked_pkg_info;
				Gtk.TreeSelection selection = aur_treeview.get_selection ();
				aur_treeview.get_path_at_pos ((int) event.x, (int) event.y, out treepath, null, null, null);
				clicked_pkg_info = aur_list.get_pkg_at_path (treepath);
				if (clicked_pkg_info == null) {
					return true;
				}
				if (!selection.path_is_selected (treepath)) {
					selection.unselect_all ();
					selection.select_path (treepath);
				}
				GLib.List<Gtk.TreePath> selected_paths = selection.get_selected_rows (null);
				deselect_item.set_sensitive (false);
				install_item.set_sensitive (false);
				remove_item.set_sensitive (false);
				reinstall_item.set_sensitive (false);
				install_optional_deps_item.set_sensitive (false);
				explicitly_installed_item.set_sensitive (false);
				selected_pkgs = new Alpm.List<unowned Alpm.Package?> ();
				selected_aur = new GLib.List<unowned Json.Object> ();
				foreach (unowned Gtk.TreePath path in selected_paths) {
					unowned Alpm.Package? pkg = alpm_config.handle.localdb.get_pkg (clicked_pkg_info.get_string_member ("Name"));
					if (pkg != null) {
						selected_pkgs.add (pkg);
						// there is for sure a pkg to remove
						remove_item.set_sensitive (true);
					} else {
						selected_aur.append (aur_list.get_pkg_at_path (path));
					}
				}
				foreach (var pkg_info in selected_aur) {
					if (transaction.to_build.contains (pkg_info.get_string_member ("Name"))) {
						deselect_item.set_sensitive (true);
						break;
					}
				}
				foreach (var pkg_info in selected_aur) {
					if (!transaction.to_build.contains (pkg_info.get_string_member ("Name"))) {
						install_item.set_sensitive (true);
						break;
					}
				}
				foreach (var pkg in selected_pkgs) {
					if (transaction.to_remove.contains (pkg.name)) {
						deselect_item.set_sensitive (true);
						break;
					}
				}
				right_click_menu.popup (null, null, null, event.button, event.time);
				return true;
			} else {
				return false;
			}
		}

		[GtkCallback]
		public void on_packages_name_column_clicked () {
			Gtk.SortType new_order;
			if (!packages_name_column.sort_indicator) {
				new_order = Gtk.SortType.ASCENDING;
			} else {
				if (sortinfo.sort_type == Gtk.SortType.ASCENDING) {
					new_order =  Gtk.SortType.DESCENDING;
				} else {
					new_order =  Gtk.SortType.ASCENDING;
				}
			}
			packages_list.sort_by_name (new_order);
			// force a display refresh
			packages_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_aur_name_column_clicked () {
			Gtk.SortType new_order;
			if (!aur_name_column.sort_indicator) {
				new_order = Gtk.SortType.ASCENDING;
			} else {
				if (sortinfo.sort_type == Gtk.SortType.ASCENDING) {
					new_order =  Gtk.SortType.DESCENDING;
				} else {
					new_order =  Gtk.SortType.ASCENDING;
				}
			}
			aur_list.sort_by_name (new_order);
			// force a display refresh
			aur_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_packages_state_column_clicked () {
			Gtk.SortType new_order;
			if (!packages_state_column.sort_indicator) {
				new_order = Gtk.SortType.ASCENDING;
			} else {
				if (sortinfo.sort_type == Gtk.SortType.ASCENDING) {
					new_order =  Gtk.SortType.DESCENDING;
				} else {
					new_order =  Gtk.SortType.ASCENDING;
				}
			}
			packages_list.sort_by_state (new_order);
			// force a display refresh
			packages_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_aur_state_column_clicked () {
			Gtk.SortType new_order;
			if (!aur_state_column.sort_indicator) {
				new_order = Gtk.SortType.ASCENDING;
			} else {
				if (sortinfo.sort_type == Gtk.SortType.ASCENDING) {
					new_order =  Gtk.SortType.DESCENDING;
				} else {
					new_order =  Gtk.SortType.ASCENDING;
				}
			}
			aur_list.sort_by_state (new_order);
			// force a display refresh
			aur_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_packages_version_column_clicked () {
			Gtk.SortType new_order;
			if (!packages_version_column.sort_indicator) {
				new_order = Gtk.SortType.ASCENDING;
			} else {
				if (sortinfo.sort_type == Gtk.SortType.ASCENDING) {
					new_order =  Gtk.SortType.DESCENDING;
				} else {
					new_order =  Gtk.SortType.ASCENDING;
				}
			}
			packages_list.sort_by_version (new_order);
			// force a display refresh
			packages_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_aur_version_column_clicked () {
			Gtk.SortType new_order;
			if (!aur_version_column.sort_indicator) {
				new_order = Gtk.SortType.ASCENDING;
			} else {
				if (sortinfo.sort_type == Gtk.SortType.ASCENDING) {
					new_order =  Gtk.SortType.DESCENDING;
				} else {
					new_order =  Gtk.SortType.ASCENDING;
				}
			}
			aur_list.sort_by_version (new_order);
			// force a display refresh
			aur_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_packages_repo_column_clicked () {
			Gtk.SortType new_order;
			if (!packages_repo_column.sort_indicator) {
				new_order = Gtk.SortType.ASCENDING;
			} else {
				if (sortinfo.sort_type == Gtk.SortType.ASCENDING) {
					new_order =  Gtk.SortType.DESCENDING;
				} else {
					new_order =  Gtk.SortType.ASCENDING;
				}
			}
			packages_list.sort_by_repo (new_order);
			// force a display refresh
			packages_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_packages_size_column_clicked () {
			Gtk.SortType new_order;
			if (!packages_size_column.sort_indicator) {
				new_order = Gtk.SortType.ASCENDING;
			} else {
				if (sortinfo.sort_type == Gtk.SortType.ASCENDING) {
					new_order =  Gtk.SortType.DESCENDING;
				} else {
					new_order =  Gtk.SortType.ASCENDING;
				}
			}
			packages_list.sort_by_size (new_order);
			// force a display refresh
			packages_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_aur_votes_column_clicked () {
			Gtk.SortType new_order;
			if (!aur_votes_column.sort_indicator) {
				new_order = Gtk.SortType.ASCENDING;
			} else {
				if (sortinfo.sort_type == Gtk.SortType.ASCENDING) {
					new_order =  Gtk.SortType.DESCENDING;
				} else {
					new_order =  Gtk.SortType.ASCENDING;
				}
			}
			aur_list.sort_by_votes (new_order);
			// force a display refresh
			aur_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_search_entry_activate () {
			unowned string search_string = search_entry.get_text ();
			if (search_string != "") {
				this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
				Gtk.TreeSelection selection = search_treeview.get_selection ();
				// add search string in search_list if needed
				bool found = false;
				// check if search string is already selected in search list
				search_list.foreach ((_model, _path, _iter) => {
					GLib.Value line;
					_model.get_value (_iter, 0, out line);
					if ((string) line == search_string) {
						found = true;
						// we select the iter in search_list
						// it will populate the list with the selection changed signal
						selection.select_iter (_iter);
					}
					return found;
				});
				if (!found) {
					Gtk.TreeIter? iter;
					search_list.insert_with_values (out iter, -1, 0, search_string);
					// we select the iter in search_list
					// it will populate the list with the selection changed signal
					selection.select_iter (iter);
				}
			}
		}

		[GtkCallback]
		public void  on_search_entry_icon_press (Gtk.EntryIconPosition p0, Gdk.Event? p1) {
			on_search_entry_activate ();
		}

		[GtkCallback]
		public void on_search_treeview_selection_changed () {
			Gtk.TreeModel model;
			Gtk.TreeIter? iter;
			Gtk.TreeSelection selection = search_treeview.get_selection ();
			if (selection.get_selected (out model, out iter)) {
				this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
				GLib.Value val;
				model.get_value (iter, 0, out val);
				string search_string = val.get_string ();
				switch (packages_notebook.get_current_page ()) {
					case 0:
						search_all_dbs.begin (search_string, (obj, res) => {
							var pkgs = search_all_dbs.end (res);
							if (search_aur_button.get_active ()) {
								search_in_aur.begin (search_string);
							}
							populate_packages_list ((owned) pkgs);
						});
						break;
					case 1:
						search_in_aur.begin (search_string, (obj, res) => {
							populate_aur_list (aur_search_results.lookup (search_string));
						});
						break;
					default:
						break;
				}
			}
		}

		[GtkCallback]
		public void on_groups_treeview_selection_changed () {
			Gtk.TreeModel model;
			Gtk.TreeIter? iter;
			Gtk.TreeSelection selection = groups_treeview.get_selection ();
			if (selection.get_selected (out model, out iter)) {
				this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
				GLib.Value grp_name;
				model.get_value (iter, 0, out grp_name);
				get_group_pkgs.begin ((string) grp_name, (obj, res) => {
					var pkgs = get_group_pkgs.end (res);
					populate_packages_list ((owned) pkgs);
				});
			}
		}

		[GtkCallback]
		public void on_states_treeview_selection_changed () {
			Gtk.TreeModel model;
			Gtk.TreeIter? treeiter;
			Gtk.TreeSelection selection = states_treeview.get_selection ();
			if (selection.get_selected (out model, out treeiter)) {
				this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
				GLib.Value val;
				model.get_value (treeiter, 0, out val);
				unowned string state = val.get_string ();
				if (state == dgettext (null, "To install")) {
					var pkgs = new Alpm.List<unowned Alpm.Package?> ();
					foreach (unowned string pkgname in transaction.to_add) {
						unowned Alpm.Package? pkg = alpm_config.handle.localdb.get_pkg (pkgname);
						if (pkg == null) {
							pkg = get_sync_pkg (pkgname);
						}
						if (pkg != null) {
							pkgs.add (pkg);
						}
					}
					populate_packages_list ((owned) pkgs);
				} else if (state == dgettext (null, "To remove")) {
					var pkgs = new Alpm.List<unowned Alpm.Package?> ();
					foreach (unowned string pkgname in transaction.to_remove) {
						unowned Alpm.Package? pkg = alpm_config.handle.localdb.get_pkg (pkgname);
						if (pkg != null) {
							pkgs.add (pkg);
						}
					}
					populate_packages_list ((owned) pkgs);
				} else if (state == dgettext (null, "Installed")) {
					get_installed_pkgs.begin ((obj, res) => {
						var pkgs = get_installed_pkgs.end (res);
						populate_packages_list ((owned) pkgs);
					});
				} else if (state == dgettext (null, "Uninstalled")) {
					//get_sync_pkgs.begin ((obj, res) => {
						//var pkgs = get_sync_pkgs.end (res);
						//populate_packages_list ((owned) pkgs);
					//});
				} else if (state == dgettext (null, "Orphans")) {
					get_orphans.begin ((obj, res) => {
						var pkgs = get_orphans.end (res);
						populate_packages_list ((owned) pkgs);
					});
				}
			}
		}

		[GtkCallback]
		public void on_repos_treeview_selection_changed () {
			Gtk.TreeModel model;
			Gtk.TreeIter? iter;
			Gtk.TreeSelection selection = repos_treeview.get_selection ();
			if (selection.get_selected (out model, out iter)) {
				this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
				GLib.Value val;
				model.get_value (iter, 0, out val);
				unowned string repo = val.get_string ();
				if (repo == dgettext (null, "local")) {
					get_local_pkgs.begin ((obj, res) => {
						var pkgs = get_local_pkgs.end (res);
						populate_packages_list ((owned) pkgs);
					});
				} else {
					get_repo_pkgs.begin (repo, (obj, res) => {
						var pkgs = get_repo_pkgs.end (res);
						populate_packages_list ((owned) pkgs);
					});
				}
			}
		}

		[GtkCallback]
		public void on_filters_notebook_switch_page (Gtk.Widget page, uint page_num) {
			refresh_packages_list ();
		}

		[GtkCallback]
		public void on_history_item_activate () {
			var file = GLib.File.new_for_path ("/var/log/pamac.log");
			if (!file.query_exists ()) {
				GLib.stderr.printf ("File '%s' doesn't exist.\n", file.get_path ());
			} else {
				StringBuilder text = new StringBuilder ();
				try {
					// Open file for reading and wrap returned FileInputStream into a
					// DataInputStream, so we can read line by line
					var dis = new DataInputStream (file.read ());
					string line;
					// Read lines until end of file (null) is reached
					while ((line = dis.read_line ()) != null) {
						// construct text in reverse order
						text.prepend (line + "\n");
					}
				} catch (GLib.Error e) {
					GLib.stderr.printf ("%s\n", e.message);
				}
				var history_dialog = new HistoryDialog (this);
				history_dialog.textview.buffer.set_text (text.str, (int) text.len);
				history_dialog.show ();
				history_dialog.response.connect (() => {
					history_dialog.destroy ();
				});
				while (Gtk.events_pending ()) {
					Gtk.main_iteration ();
				}
			}
		}

		[GtkCallback]
		public void on_local_item_activate () {
			Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
					dgettext (null, "Install Local Packages"), this, Gtk.FileChooserAction.OPEN,
					dgettext (null, "_Cancel"), Gtk.ResponseType.CANCEL,
					dgettext (null, "_Open"),Gtk.ResponseType.ACCEPT);
			chooser.window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
			chooser.icon_name = "system-software-install";
			chooser.default_width = 900;
			chooser.select_multiple = true;
			chooser.local_only = false;
			chooser.create_folders = false;
			Gtk.FileFilter package_filter = new Gtk.FileFilter ();
			package_filter.set_filter_name (dgettext (null, "Alpm Package"));
			package_filter.add_pattern ("*.pkg.tar.xz");
			chooser.add_filter (package_filter);
			if (chooser.run () == Gtk.ResponseType.ACCEPT) {
				SList<string> packages_paths = chooser.get_filenames ();
				if (packages_paths.length () != 0) {
					foreach (unowned string path in packages_paths) {
						transaction.to_load.add (path);
					}
					this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
					chooser.destroy ();
					while (Gtk.events_pending ()) {
						Gtk.main_iteration ();
					}
					transaction.run ();
				}
			} else {
				chooser.destroy ();
				while (Gtk.events_pending ()) {
					Gtk.main_iteration ();
				}
			}
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
		public void on_preferences_item_activate () {
			run_preferences_dialog.begin ();
		}

		[GtkCallback]
		public void on_about_item_activate () {
			Gtk.show_about_dialog (
				this,
				"program_name", "Pamac",
				"logo_icon_name", "system-software-install",
				"comments", dgettext (null, "A Gtk3 frontend for libalpm"),
				"copyright", dgettext (null, "Copyright © 2015 Guillaume Benoit"),
				"version", VERSION,
				"license_type", Gtk.License.GPL_3_0,
				"website", "http://manjaro.org");
		}

		[GtkCallback]
		public void on_valid_button_clicked () {
			this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
			transaction.run ();
		}

		[GtkCallback]
		public void on_cancel_button_clicked () {
			transaction.clear_lists ();
			set_buttons_sensitive (false);
			// force a display refresh
			packages_treeview.queue_draw ();
			aur_treeview.queue_draw ();
		}

		[GtkCallback]
		public void on_refresh_button_clicked () {
			this.get_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.WATCH));
			transaction.start_refresh (false);
		}

		public void on_transaction_finished (bool database_modified) {
			if (database_modified) {
				set_buttons_sensitive (false);
				refresh_handle ();
				refresh_packages_list ();
			} else {
				this.get_window ().set_cursor (null);
			}
			transaction.to_load.remove_all ();
		}
	}
}
